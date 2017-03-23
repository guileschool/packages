/*
 Copyright (c) 2016, Stephane Sudre
 All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 - Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 - Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 - Neither the name of the WhiteBox nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "PKGPackagePayloadViewController.h"

#import "PKGApplicationPreferences.h"

#import "PKGPackagePayloadDataSource.h"



#import "PKGFilesEmptySelectionInspectorViewController.h"
#import "PKGPayloadFilesSelectionInspectorViewController.h"

#import "NSOutlineView+Selection.h"

#import "PKGPayloadTreeNode+UI.h"

@interface PKGPackagePayloadViewController ()
{
	IBOutlet NSPopUpButton * _payloadTypePopUpButton;
	IBOutlet NSButton * _splitForksCheckbox;
	
	IBOutlet NSTextField * _defaultDestinationLabel;
	IBOutlet NSButton * _defaultDestinationSetButton;
	
	IBOutlet NSView * _hierarchyPlaceHolderView;
	IBOutlet NSView * _inspectorPlaceHolderView;
	
	PKGViewController *_emptySelectionInspectorViewController;
	PKGPayloadFilesSelectionInspectorViewController * _selectionInspectorViewController;
	
	PKGViewController *_currentInspectorViewController;
	
	PKGPackagePayloadDataSource * _dataSource;
}

	@property (readwrite) PKGPayloadFilesHierarchyViewController * payloadHierarchyViewController;

- (void)_updateLayout;

- (IBAction)switchPayloadType:(id)sender;

- (IBAction)setDefaultDestination:(id)sender;

- (IBAction)switchHiddenFolderTemplatesVisibility:(id)sender;

// Notifications

- (void)fileHierarchySelectionDidChange:(NSNotification *)inNotification;

- (void)fileHierarchyDidRenameFolder:(NSNotification *)inNotification;

- (void)advancedModeStateDidChange:(NSNotification *)inNotification;

@end

@implementation PKGPackagePayloadViewController

- (instancetype)initWithDocument:(PKGDocument *)inDocument
{
	self=[super initWithDocument:inDocument];
	
	if (self!=nil)
	{
		_dataSource=[PKGPackagePayloadDataSource new];
		_dataSource.filePathConverter=self.filePathConverter;
		
		_payloadHierarchyViewController=[[PKGPayloadFilesHierarchyViewController alloc] initWithDocument:inDocument];
		
		_payloadHierarchyViewController.label=@"Payload";
		_payloadHierarchyViewController.hierarchyDataSource=_dataSource;
		_payloadHierarchyViewController.disclosedStateKey=@"ui.package.payload.disclosed";
	}
	
	return self;
}

- (NSString *)nibName
{
	return @"PKGPackagePayloadViewController";
}

- (void)WB_viewDidLoad
{
	[super WB_viewDidLoad];
	
	// Files Hierarchy
	
	_payloadHierarchyViewController.view.frame=_hierarchyPlaceHolderView.bounds;
	
	[_hierarchyPlaceHolderView addSubview:_payloadHierarchyViewController.view];
}

#pragma mark -

- (NSUInteger)tag
{
	return PKGPreferencesGeneralPackageProjectPanePayload;
}

#pragma mark -

- (void)WB_viewWillAppear
{
	[super WB_viewWillAppear];
	
	[self _updateLayout];
	
	[_payloadTypePopUpButton selectItemWithTag:self.payload.type];
	
	_splitForksCheckbox.state=(self.payload.splitForksIfNeeded==YES) ? NSOnState : NSOffState;
	
	_defaultDestinationLabel.stringValue=self.payload.defaultInstallLocation;
	
	_dataSource.rootNodes=self.payload.filesTree.rootNodes;
	
	_dataSource.delegate=_payloadHierarchyViewController;
	_dataSource.installLocationNode=[self.payload.filesTree.rootNode descendantNodeAtPath:self.payload.defaultInstallLocation];
	
	if (_dataSource.installLocationNode==nil)
	{
		// A COMPLETER
	}
	
	[_payloadHierarchyViewController WB_viewWillAppear];
}

- (void)WB_viewDidAppear
{
	[super WB_viewDidAppear];
	
	//[self.view.window makeFirstResponder:_payloadHierarchyViewController.outlineView];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(advancedModeStateDidChange:) name:PKGPreferencesAdvancedAdvancedModeStateDidChangeNotification object:nil];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(fileHierarchySelectionDidChange:) name:NSOutlineViewSelectionDidChangeNotification object:_payloadHierarchyViewController.outlineView];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(fileHierarchyDidRenameFolder:) name:PKGFilesHierarchyDidRenameFolderNotification object:_payloadHierarchyViewController.outlineView];
	
	[_payloadHierarchyViewController WB_viewDidAppear];
	
	[self fileHierarchySelectionDidChange:[NSNotification notificationWithName:NSOutlineViewSelectionDidChangeNotification object:_payloadHierarchyViewController.outlineView]];
}

- (void)WB_viewWillDisappear
{
	[super WB_viewWillDisappear];
	
	[[NSNotificationCenter defaultCenter] removeObserver:self name:PKGPreferencesAdvancedAdvancedModeStateDidChangeNotification object:nil];
	
	[[NSNotificationCenter defaultCenter] removeObserver:self name:NSOutlineViewSelectionDidChangeNotification object:nil];
	
	[[NSNotificationCenter defaultCenter] removeObserver:self name:PKGFilesHierarchyDidRenameFolderNotification object:nil];
	
	[_payloadHierarchyViewController WB_viewWillDisappear];
}

- (void)WB_viewDidDisappear
{
	[super WB_viewDidDisappear];
	
	[_payloadHierarchyViewController WB_viewDidDisappear];
}

#pragma mark -

- (void)_updateLayout
{
	BOOL tAdvancedModeEnabled=[PKGApplicationPreferences sharedPreferences].advancedMode;
	
	_splitForksCheckbox.hidden=(tAdvancedModeEnabled==NO);
}

#pragma mark -

- (IBAction)switchPayloadType:(id)sender
{
	// A COMPLETER
}

- (IBAction)setDefaultDestination:(id)sender
{
	NSOutlineView * tOutlineView=_payloadHierarchyViewController.outlineView;
	NSIndexSet * tClickedOrSelectedIndexes=tOutlineView.WB_selectedOrClickedRowIndexes;
	
	if (tClickedOrSelectedIndexes.count!=1)
		return;
	
	_defaultDestinationSetButton.enabled=NO;
	
	PKGPayloadTreeNode * tPreviousDefaultInstallationLocationNode=_dataSource.installLocationNode;
	_dataSource.installLocationNode=[tOutlineView itemAtRow:tClickedOrSelectedIndexes.firstIndex];
	
	NSMutableIndexSet * tRowIndexes=[tClickedOrSelectedIndexes mutableCopy];
	NSInteger tIndex=[tOutlineView rowForItem:tPreviousDefaultInstallationLocationNode];
	
	if (tIndex!=-1)
		[tRowIndexes addIndex:tIndex];
	
	self.payload.defaultInstallLocation=[_dataSource.installLocationNode filePath];
	_defaultDestinationLabel.stringValue=self.payload.defaultInstallLocation;
	
	[tOutlineView reloadDataForRowIndexes:tRowIndexes
							columnIndexes:[NSIndexSet indexSetWithIndex:[tOutlineView columnWithIdentifier:@"file.name"]]];
	
	[self noteDocumentHasChanged];
}

- (IBAction)switchHiddenFolderTemplatesVisibility:(id)sender
{
	self.payload.hiddenFolderTemplatesIncluded=!self.payload.hiddenFolderTemplatesIncluded;
	
	if (self.payload.hiddenFolderTemplatesIncluded==YES)
		[_payloadHierarchyViewController showHiddenFolderTemplates];
	else
		[_payloadHierarchyViewController hideHiddenFolderTemplates];
	
	[self noteDocumentHasChanged];
}

#pragma mark -

- (BOOL)validateMenuItem:(NSMenuItem *)inMenuItem
{
	SEL tAction=inMenuItem.action;
	
	// Set Default Location
	
	if (tAction==@selector(setDefaultDestination:))
	{
		NSOutlineView * tOutlineView=_payloadHierarchyViewController.outlineView;
		NSIndexSet * tClickedOrSelectedIndexes=tOutlineView.WB_selectedOrClickedRowIndexes;
		
		if (tClickedOrSelectedIndexes.count!=1)
			return NO;
		
		PKGPayloadTreeNode * tSelectedTreeNode=[tOutlineView itemAtRow:tClickedOrSelectedIndexes.firstIndex];
		
		if (tSelectedTreeNode==_dataSource.installLocationNode)
			return NO;
		
		return [tSelectedTreeNode isSelectableAsInstallationLocation];
	}
	
	// Show|Hide Hidden Folders
	
	if (tAction==@selector(switchHiddenFolderTemplatesVisibility:))
	{
		[inMenuItem setTitle:(self.payload.hiddenFolderTemplatesIncluded==YES) ? NSLocalizedString(@"Hide Hidden Folders", @"") : NSLocalizedString(@"Show Hidden Folders", @"")];
		 
		 return YES;
	}
	
	// A COMPLETER
	
	return YES;
}

#pragma mark - Notifications

- (void)fileHierarchySelectionDidChange:(NSNotification *)inNotification
{
	NSOutlineView * tOutlineView=_payloadHierarchyViewController.outlineView;
	
	if (inNotification.object!=tOutlineView)
		return;
	
	NSUInteger tNumberOfSelectedRows=tOutlineView.numberOfSelectedRows;
	
	// Inspector
	
	if (tNumberOfSelectedRows==0)
	{
		if (_emptySelectionInspectorViewController==nil)
			_emptySelectionInspectorViewController=[PKGFilesEmptySelectionInspectorViewController new];
		
		if (_currentInspectorViewController!=_emptySelectionInspectorViewController)
		{
			[_currentInspectorViewController WB_viewWillDisappear];
			
			[_currentInspectorViewController.view removeFromSuperview];
			
			[_currentInspectorViewController WB_viewDidDisappear];
			
			_currentInspectorViewController=_emptySelectionInspectorViewController;
			
			_currentInspectorViewController.view.frame=_inspectorPlaceHolderView.bounds;
			
			[_currentInspectorViewController WB_viewWillAppear];
			
			[_inspectorPlaceHolderView addSubview:_currentInspectorViewController.view];
			
			[_currentInspectorViewController WB_viewDidAppear];
		}
	}
	else
	{
		if (_selectionInspectorViewController==nil)
		{
			_selectionInspectorViewController=[[PKGPayloadFilesSelectionInspectorViewController alloc] initWithDocument:self.document];
			_selectionInspectorViewController.delegate=_payloadHierarchyViewController;
		}
		
		if (_currentInspectorViewController!=_selectionInspectorViewController)
		{
			[_currentInspectorViewController WB_viewWillDisappear];
			
			[_currentInspectorViewController.view removeFromSuperview];
			
			[_currentInspectorViewController WB_viewDidDisappear];

			
			_currentInspectorViewController=_selectionInspectorViewController;
			
			_currentInspectorViewController.view.frame=_inspectorPlaceHolderView.bounds;
			
			[_currentInspectorViewController WB_viewWillAppear];
			
			[_inspectorPlaceHolderView addSubview:_currentInspectorViewController.view];
			
			[_currentInspectorViewController WB_viewDidAppear];
		}
		
		_selectionInspectorViewController.selectedItems=[tOutlineView WB_selectedItems];
		_selectionInspectorViewController.delegate=_payloadHierarchyViewController;
	}
	
	// Default Destination
	
	if (tNumberOfSelectedRows!=1)
	{
		_defaultDestinationSetButton.enabled=NO;
		return;
	}
	
	PKGPayloadTreeNode * tSelectedTreeNode=[tOutlineView itemAtRow:tOutlineView.selectedRow];
	
	if (tSelectedTreeNode==_dataSource.installLocationNode)
	{
		_defaultDestinationSetButton.enabled=NO;
		return;
	}
	
	_defaultDestinationSetButton.enabled=[tSelectedTreeNode isSelectableAsInstallationLocation];
		
	// A COMPLETER
}

- (void)fileHierarchyDidRenameFolder:(NSNotification *)inNotification
{
	NSOutlineView * tOutlineView=_payloadHierarchyViewController.outlineView;
	
	if (inNotification.object!=tOutlineView)
		return;
	
	PKGPayloadTreeNode * tTreeNode=inNotification.userInfo[@"NSObject"];
	
	if (tTreeNode==_dataSource.installLocationNode)
	{
		self.payload.defaultInstallLocation=[_dataSource.installLocationNode filePath];
		_defaultDestinationLabel.stringValue=self.payload.defaultInstallLocation;
	}
}

- (void)advancedModeStateDidChange:(NSNotification *)inNotification
{
	[self _updateLayout];
}

@end
