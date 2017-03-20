/*
 Copyright (c) 2017, Stephane Sudre
 All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 - Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 - Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 - Neither the name of the WhiteBox nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "PKGDistributionRequirementSourceListDataSource.h"

#import "PKGDistributionRequirementSourceListFlatTree.h"
#import "PKGDistributionRequirementSourceListNode.h"
#import "PKGDistributionRequirementSourceListGroupItem.h"
#import "PKGDistributionRequirementSourceListRequirementItem.h"

#import "NSOutlineView+Selection.h"

#import "PKGDistributionRequirementPanel.h"

#import "PKGRequirementPluginsManager.h"

#import "PKGRequirement+UI.h"

#import "NSArray+UniqueName.h"

#import "NSIndexSet+Analysis.h"

NSString * const PKGDistributionRequirementInternalPboardType=@"fr.whitebox.packages.internal.distribution.requirements";

@interface PKGDistributionRequirementSourceListDataSource ()
{
	PKGDistributionRequirementSourceListFlatTree * _flatTree;
	
	NSIndexSet * _internalDragData;
}

- (void)tableView:(NSTableView *)inTableView addRequirement:(PKGRequirement *)inRequirement completionHandler:(void(^)(BOOL))handler;
- (void)tableView:(NSTableView *)inTableView addRequirements:(NSArray *)inRequirements completionHandler:(void(^)(BOOL))handler;

@end

@implementation PKGDistributionRequirementSourceListDataSource

+ (NSArray *)supportedDraggedTypes
{
	return @[NSFilenamesPboardType,PKGDistributionRequirementInternalPboardType];
}

- (void)dealloc
{
	_internalDragData=nil;
}

- (void)setRequirements:(NSMutableArray *)inRequirements
{
	if (_requirements!=inRequirements)
	{
		_requirements=inRequirements;
		
		_flatTree=[[PKGDistributionRequirementSourceListFlatTree alloc] initWithRequirements:_requirements];
	}
}

#pragma mark -

- (NSUInteger)numberOfItems
{
	return _flatTree.count;
}

#pragma mark - NSTableViewDataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)inTableView
{
	if (_flatTree==nil)
		return 0;
	
	return _flatTree.count;
}

#pragma mark - Drag and Drop support

- (BOOL)tableView:(NSTableView *)inTableView writeRowsWithIndexes:(NSIndexSet *)inRowIndexes toPasteboard:(NSPasteboard *)inPasteboard;
{
	NSMutableSet * tMutableSet=[NSMutableSet set];
	
	NSArray * tItems=[_flatTree nodesAtIndexes:inRowIndexes];
	
	for(PKGDistributionRequirementSourceListNode * tNode in tItems)
	{
		PKGDistributionRequirementSourceListNode * tParent=tNode.parent;
		
		if (tParent==nil)
			return NO;
		
		[tMutableSet addObject:tParent];
	}
	
	if (tMutableSet.count!=1)	// Only one type of requirements in a drag
		return NO;
	
	_internalDragData=inRowIndexes;	// A COMPLETER (Find how to empty it when the drag and drop is done)
	
	[inPasteboard declareTypes:@[PKGDistributionRequirementInternalPboardType] owner:self];		// Make the external drag a promised case since it will be less usual IMHO
	
	[inPasteboard setData:[NSData data] forType:PKGDistributionRequirementInternalPboardType];
	
	return YES;
}

- (NSDragOperation)tableView:(NSTableView *)inTableView validateDrop:(id <NSDraggingInfo>)info proposedRow:(NSInteger)inRow proposedDropOperation:(NSTableViewDropOperation)inDropOperation
{
	if (inDropOperation==NSTableViewDropOn)
		return NSDragOperationNone;
	
	NSPasteboard * tPasteBoard=[info draggingPasteboard];
	
	// Internal Drag
	
	if ([tPasteBoard availableTypeFromArray:@[PKGDistributionRequirementInternalPboardType]]!=nil && [info draggingSource]==inTableView)
	{
		PKGDistributionRequirementSourceListNode * tDroppedNode=[_flatTree nodeAtIndex:_internalDragData.firstIndex];
		NSUInteger tFirstDroppableRow=[_flatTree indexOfNode:tDroppedNode.parent];
		NSUInteger tLastDroppableRow=tDroppedNode.parent.numberOfChildren+tFirstDroppableRow;
		
		NSLog(@"%ld %ld",(long)tFirstDroppableRow,(long)tLastDroppableRow);
		
		if (inRow<tFirstDroppableRow || inRow>(tLastDroppableRow+1))
			return NSDragOperationNone;
		
		if ([_internalDragData WB_containsOnlyOneRange]==YES)
		{
			NSUInteger tFirstIndex=_internalDragData.firstIndex;
			NSUInteger tLastIndex=_internalDragData.lastIndex;
			
			if (inRow>=tFirstIndex && inRow<=(tLastIndex+1))
				return NSDragOperationNone;
		}
		else
		{
			if ([_internalDragData containsIndex:(inRow-1)]==YES)
				return NSDragOperationNone;
		}
		
		return NSDragOperationMove;
	}
	
	// A COMPLETER
	
	return NSDragOperationNone;
}

- (BOOL)tableView:(NSTableView *)inTableView acceptDrop:(id <NSDraggingInfo>)info row:(NSInteger)inRow dropOperation:(NSTableViewDropOperation)inDropOperation
{
	if (inTableView==nil)
		return NO;
	
	// Internal drag and drop
	
	NSPasteboard * tPasteBoard=[info draggingPasteboard];
	
	if ([tPasteBoard availableTypeFromArray:@[PKGDistributionRequirementInternalPboardType]]!=nil && [info draggingSource]==inTableView)
	{
		NSArray * tNodes=[_flatTree nodesAtIndexes:_internalDragData];
		PKGDistributionRequirementSourceListNode * tParent=((PKGDistributionRequirementSourceListNode *)tNodes.lastObject).parent;
		
		[_flatTree removeNodesInArray:tNodes];
		
		NSUInteger tIndex=[_internalDragData firstIndex];
		
		while (tIndex!=NSNotFound)
		{
			if (tIndex<inRow)
				inRow--;
			
			tIndex=[_internalDragData indexGreaterThanIndex:tIndex];
		}
		
		[_flatTree insertNodes:tNodes atIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(inRow, tNodes.count)]];
		
		for(PKGDistributionRequirementSourceListNode * tNode in tNodes)
			tNode.parent=tParent;
		
		_internalDragData=nil;
		
		[inTableView deselectAll:nil];
		
		[self.delegate sourceListDataDidChange:self];
		
		[inTableView reloadData];
		
		[inTableView selectRowIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(inRow,_internalDragData.count)]
				 byExtendingSelection:NO];
		
		return YES;
	}
	
	// A COMPLETER
	
	return NO;
}

#pragma mark -

- (void)tableView:(NSTableView *)inTableView addNewRequirementWithCompletionHandler:(void(^)(BOOL))handler
{
	PKGRequirement * tNewRequirement=[PKGRequirement new];
	
	tNewRequirement.identifier=@"fr.whitebox.Packages.requirement.os";
	
	PKGDistributionRequirementPanel * tRequirementPanel=[PKGDistributionRequirementPanel distributionRequirementPanel];
	tRequirementPanel.prompt=NSLocalizedString(@"Add", @"");
	tRequirementPanel.requirement=tNewRequirement;
	
	[tRequirementPanel beginSheetModalForWindow:inTableView.window completionHandler:^(NSInteger bResult) {
		
		if (bResult==PKGPanelCancelButton)
			return;
		
		NSString * tBaseName=[[PKGRequirementPluginsManager defaultManager] localizedPluginNameForIdentifier:tNewRequirement.identifier];
		
		tNewRequirement.name=[self.requirements uniqueNameWithBaseName:tBaseName usingNameExtractor:^NSString *(PKGRequirement * bRequirement,NSUInteger bIndex) {
			
			return bRequirement.name;
		}];
		
		if (tNewRequirement.name==nil)
		{
			NSLog(@"Could not determine a unique name for the requirement");
			
			tNewRequirement.name=@"";
		}
		
		[self tableView:inTableView addRequirement:tNewRequirement completionHandler:handler];
	}];
}

- (void)editRequirement:(NSTableView *)inTableView
{
	NSUInteger tIndex=inTableView.WB_selectedOrClickedRowIndexes.firstIndex;
	PKGDistributionRequirementSourceListNode * tTreeNode=[_flatTree nodeAtIndex:tIndex];
	PKGDistributionRequirementSourceListRequirementItem * tRequirementItem=(PKGDistributionRequirementSourceListRequirementItem *)tTreeNode.representedObject;
	PKGRequirement * tOriginalRequirement=tRequirementItem.requirement;
	PKGRequirement * tEditedRequirement=[tOriginalRequirement copy];

	PKGDistributionRequirementPanel * tRequirementPanel=[PKGDistributionRequirementPanel distributionRequirementPanel];

	tRequirementPanel.requirement=tEditedRequirement;

	[tRequirementPanel beginSheetModalForWindow:inTableView.window completionHandler:^(NSInteger bResult) {

		if (bResult==PKGPanelCancelButton)
				return;

		if ([tEditedRequirement isEqualToRequirement:tOriginalRequirement]==YES)
			return;

		NSUInteger tIndex=[self.requirements indexOfObjectIdenticalTo:tOriginalRequirement];
		
		if (tIndex==NSNotFound)
			return;
		
		PKGRequirementType tOriginalRequirementType=tOriginalRequirement.requirementType;
		PKGRequirementType tEditedRequirementType=tEditedRequirement.requirementType;
		
		if (tOriginalRequirementType==tEditedRequirementType)
		{
			[self.requirements replaceObjectAtIndex:tIndex withObject:tEditedRequirement];
			
			[tTreeNode setRepresentedObject:[[PKGDistributionRequirementSourceListRequirementItem alloc] initWithRequirement:tEditedRequirement]];
			
			[self.delegate sourceListDataDidChange:self];
			
			return;
		}
		
		dispatch_async(dispatch_get_main_queue(), ^{
		
			[self.requirements removeObject:tOriginalRequirement];
			
			[_flatTree removeNode:tTreeNode];
			
			[self tableView:inTableView addRequirement:tEditedRequirement completionHandler:nil];
		});
	}];
}

#pragma mark -

- (id)itemAtIndex:(NSUInteger)inIndex
{
	return [_flatTree nodeAtIndex:inIndex];
}

- (NSArray *)itemsAtIndexes:(NSIndexSet *)inIndexSet
{
	return [_flatTree nodesAtIndexes:inIndexSet];
}

- (NSInteger)rowForItem:(id)inItem
{
	if (inItem==nil)
		return -1;
	
	NSUInteger tIndex=[_flatTree indexOfNode:inItem];
	
	return (tIndex==NSNotFound) ? -1 : tIndex;
}

- (void)tableView:(NSTableView *)inTableView setItem:(PKGDistributionRequirementSourceListNode *)inRequirementTreeNode state:(BOOL)inState
{
	if (inTableView==nil || inRequirementTreeNode==nil)
		return;
	
	PKGDistributionRequirementSourceListRequirementItem * tRequirementItem=inRequirementTreeNode.representedObject;
	PKGRequirement * tRequirement=tRequirementItem.requirement;
	
	if (tRequirement.isEnabled==inState)
		return;
	
	tRequirement.enabled=inState;
	
	[self.delegate sourceListDataDidChange:self];
}

- (void)tableView:(NSTableView *)inTableView addRequirement:(PKGRequirement *)inRequirement completionHandler:(void(^)(BOOL))handler
{
	if (inRequirement==nil)
		return;
	
	[self tableView:inTableView addRequirements:@[inRequirement] completionHandler:handler];
}

- (void)tableView:(NSTableView *)inTableView addRequirements:(NSArray *)inRequirements completionHandler:(void(^)(BOOL))handler
{
	if (inTableView==nil || inRequirements.count==0)
	{
		if (handler!=nil)
			handler(NO);
		
		return;
	}
	
	NSMutableSet * tMutableSet=[NSMutableSet set];
	
	for(PKGRequirement * tRequirement in inRequirements)
	{
		if ([self.requirements containsObject:tRequirement]==YES)
		{
			// A COMPLETER
			
			continue;
		}
		
		[self.requirements addObject:tRequirement];
		
		[_flatTree addRequirement:tRequirement];
		
		[tMutableSet addObject:tRequirement];
	}
	
	if (tMutableSet.count==0)
	{
		if (handler!=nil)
			handler(NO);
		
		return;
	}
	
	[inTableView reloadData];
	
	// Post Notification
	
	[self.delegate sourceListDataDidChange:self];
	
	NSMutableIndexSet * tMutableIndexSet=[NSMutableIndexSet indexSet];
	
	for(PKGRequirement * tRequirement in tMutableSet)
	{
		PKGDistributionRequirementSourceListNode * tTreeNode=[_flatTree treeNodeForRequirement:tRequirement];
		
		NSInteger tSelectedRow=(tTreeNode==nil) ? 0 : [_flatTree indexOfNode:tTreeNode];
		
		if (tSelectedRow==-1)
			tSelectedRow=0;
		
		[tMutableIndexSet addIndex:tSelectedRow];
	}
	
	[inTableView scrollRowToVisible:(tMutableIndexSet.firstIndex==NSNotFound) ? 0 : tMutableIndexSet.firstIndex];
	
	[inTableView selectRowIndexes:tMutableIndexSet byExtendingSelection:NO];
	
	if (handler!=nil)
		handler(YES);
}

- (BOOL)tableView:(NSTableView *)inTableView shouldRenameRequirement:(PKGDistributionRequirementSourceListNode *)inRequirementTreeNode as:(NSString *)inNewName
{
	if (inTableView==nil || inRequirementTreeNode==nil || inNewName==nil)
		return NO;
	
	PKGRequirement * tRequirement=((PKGDistributionRequirementSourceListRequirementItem *) inRequirementTreeNode.representedObject).requirement;
	NSString * tName=tRequirement.name;
	
	if ([tName compare:inNewName]==NSOrderedSame)
		return NO;
	
	if ([tName caseInsensitiveCompare:inNewName]!=NSOrderedSame)
	{
		NSUInteger tLength=inNewName.length;
		NSIndexSet * tReloadRowIndexes=[NSIndexSet indexSetWithIndex:[_flatTree indexOfNode:inRequirementTreeNode]];
		NSIndexSet * tReloadColumnIndexes=[NSIndexSet indexSetWithIndex:[inTableView columnWithIdentifier:@"requirement"]];
		
		if (tLength==0)
		{
			[inTableView reloadDataForRowIndexes:tReloadRowIndexes columnIndexes:tReloadColumnIndexes];
			return NO;
		}
	}
	
	return YES;
}

- (BOOL)tableView:(NSTableView *)inTableView renameRequirement:(PKGDistributionRequirementSourceListNode *)inRequirementTreeNode as:(NSString *)inNewName
{
	if (inTableView==nil || inRequirementTreeNode==nil || inNewName==nil)
		return NO;
	
	PKGRequirement * tRequirement=((PKGDistributionRequirementSourceListRequirementItem *) inRequirementTreeNode.representedObject).requirement;
	
	tRequirement.name=inNewName;
	
	[inTableView reloadData];
	
	[self.delegate sourceListDataDidChange:self];
	
	NSInteger tSelectedRow=[_flatTree indexOfNode:inRequirementTreeNode];
	
	if (tSelectedRow!=-1)
	{
		[inTableView scrollRowToVisible:tSelectedRow];
		[inTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:tSelectedRow] byExtendingSelection:NO];
	}
	
	return YES;
}

- (void)tableView:(NSTableView *)inTableView duplicateItems:(NSArray *)inItems
{
	if (inTableView==nil || inItems.count==0)
		return;
	
	__block NSMutableArray * tTemporaryComponents=[self.requirements mutableCopy];
	
	NSArray * tDuplicatedPackageComponents=[inItems WB_arrayByMappingObjectsLenientlyUsingBlock:^PKGRequirement *(PKGDistributionRequirementSourceListNode * bSourceListNode, NSUInteger bIndex) {
		
		PKGDistributionRequirementSourceListRequirementItem * tRequirementItem=bSourceListNode.representedObject;
		
		PKGRequirement * tNewRequirement=[tRequirementItem.requirement copy];
		
		// Unique Name
		
		__block NSString * tBaseName=tNewRequirement.name;
		
		NSString * tPattern=[NSString stringWithFormat:@"%@ ?[0-9]*$",NSLocalizedString(@" copy", @"")];
		
		NSRegularExpression * tRegularExpression=[NSRegularExpression regularExpressionWithPattern:tPattern options:NSRegularExpressionCaseInsensitive error:NULL];
		
		[tRegularExpression enumerateMatchesInString:tBaseName options:NSMatchingReportCompletion range:NSMakeRange(0,tBaseName.length) usingBlock:^(NSTextCheckingResult * bResult, NSMatchingFlags bFlags, BOOL * bOutStop) {
			
			if (bResult.resultType!=NSTextCheckingTypeRegularExpression)
				return;
			
			tBaseName=[tBaseName substringToIndex:bResult.range.location];
			
			*bOutStop=YES;
		}];
		
		NSString * tNewName=[tTemporaryComponents uniqueNameWithBaseName:[tBaseName stringByAppendingString:NSLocalizedString(@" copy", @"")]
													  usingNameExtractor:^NSString *(PKGRequirement * bRequirement, NSUInteger bIndex) {
														  return bRequirement.name;
													  }];
		
		if (tNewName!=nil)
			tNewRequirement.name=tNewName;
		
		
		[tTemporaryComponents addObject:tNewRequirement];
		
		return tNewRequirement;
	}];
	
	[self tableView:inTableView addRequirements:tDuplicatedPackageComponents completionHandler:nil];
}

- (void)tableView:(NSTableView *)inTableView removeItems:(NSArray *)inItems
{
	if (inTableView==nil || inItems.count==0)
		return;
	
	// Remove the requirements
	
	for(PKGDistributionRequirementSourceListNode * tSourceListNode in inItems)
	{
		PKGDistributionRequirementSourceListRequirementItem * tRequirementItem=tSourceListNode.representedObject;
		
		// A COMPLETER
		
		[_requirements removeObject:tRequirementItem.requirement];
		
		[_flatTree removeNode:tSourceListNode];
	}
	
	[inTableView deselectAll:nil];
	
	[inTableView reloadData];
	
	[self.delegate sourceListDataDidChange:self];
}

@end
