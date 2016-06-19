//
//  TableViewBaseAdapter.swift
//  MVVMKit
//
//  Created by Евгений Губин on 21.06.15.
//  Copyright (c) 2015 GitHub. All rights reserved.
//

import Foundation

public enum TableViewSectionView {
    case header, footer
}

public enum TableAdapterRowHeightModes {
    case automatic, templateCell, manual, `default`
}

public class TableViewBaseAdapter: NSObject, UITableViewDataSource, UITableViewDelegate {
    public typealias CellsChangedEvent = (TableViewBaseAdapter, [IndexPath]) -> ()
    public typealias CellAction = (UITableViewCell, IndexPath) -> ()
    
    let tag = "observable_array_tag"
    let slHeightForRowAtIndexPath = #selector(UITableViewDelegate.tableView(_:heightForRowAt:))
    
    // Workaround: anowned(safe) cause random crashes for NSObject descendants
    unowned(unsafe) let tableView: UITableView
    public let cells: CellViewBindingManager
    public let views = ViewBindingManager()
    public let rowHeightMode: TableAdapterRowHeightModes
    
    var updateCounter = 0
    var rowSizeCache: [IndexPath: CGSize] = [:]
    
    public weak var delegate: UITableViewDelegate? {
        didSet {
            tableView.delegate = nil
            tableView.delegate = self
        }
    }
    
    public convenience init(tableView: UITableView) {
        self.init(tableView: tableView, rowHeightMode: .default)
    }
    
    public init(tableView: UITableView, rowHeightMode: TableAdapterRowHeightModes) {
        self.tableView = tableView
        self.rowHeightMode = rowHeightMode
        cells = CellViewBindingManager(tableView: tableView)
        
        super.init()
        
        self.tableView.dataSource = self
        self.tableView.delegate = self
    }
    
    public func numberOfSections(in tableView: UITableView) -> Int {
        fatalError("Abstract method")
    }
    
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        fatalError("Abstract method")
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let viewModel = viewModelForIndexPath(indexPath)
        return cells.bindViewModel(viewModel, indexPath: indexPath)
    }
    
    func viewModelForIndexPath(_ indexPath: IndexPath) -> AnyViewModel {
        fatalError("Abstract method")
    }
    
    func viewModelForSectionHeaderAtIndex(_ index: Int) -> AnyViewModel? {
        return nil
    }
    
    func viewModelForSectionFooterAtIndex(_ index: Int) -> AnyViewModel? {
        return nil
    }
    
    public func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return nil
    }
    
    public func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return nil
    }
    
    public func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if let viewModel = viewModelForSectionHeaderAtIndex(section) {
            return views.bindViewModel(viewModel)
        }
        return nil
    }
    
    public func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        if let viewModel = viewModelForSectionFooterAtIndex(section) {
            return views.bindViewModel(viewModel)
        }
        return nil
    }
    
    public func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        let hasTitle = self.tableView(tableView, titleForHeaderInSection: section) != nil
        let hasVM = viewModelForSectionHeaderAtIndex(section) != nil
        
        return hasTitle || hasVM ? UITableViewAutomaticDimension : 0
    }
    
    public func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        let hasTitle = self.tableView(tableView, titleForFooterInSection: section) != nil
        let hasVM = viewModelForSectionFooterAtIndex(section) != nil
        
        return hasTitle || hasVM ? UITableViewAutomaticDimension : 0
    }
    
    public func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let width = rowSizeCache[indexPath]?.width ?? 0
        if width != tableView.bounds.width {
            rowSizeCache[indexPath] = cells.sizeForViewModel(viewModelForIndexPath(indexPath), atIndexPath: indexPath)
        }
        
        return rowSizeCache[indexPath]!.height
    }
    
    func invalidateRowHeightCache() {
        rowSizeCache = [:]
    }
    
    public func beginUpdate() {
        updateCounter += 1
        if updateCounter == 1 {
            tableView.beginUpdates()
        }
    }
    
    public func endUpdate() {
        precondition(updateCounter >= 0, "Batch update calls are unbalanced")
        updateCounter -= 1
        if updateCounter == 0 {
            tableView.endUpdates()
            performDelayedActions()
        }
    }
    
    var delayedActions: [(UITableView) -> ()] = []
    
    public func performAfterUpdate(_ action: (UITableView) -> ()) {
        
        if updateCounter == 0 {
            action(tableView)
        } else {
            delayedActions.append(action)
        }
    }
    
    func performDelayedActions() {
        let actions = delayedActions
        
        delayedActions.removeAll(keepingCapacity: false)
        
        for action in actions {
            action(tableView)
        }
    }
    
    deinit {
        print("deinit Adapter")
    }

    public var onCellsInserted: CellsChangedEvent?
    public var onCellsRemoved: CellsChangedEvent?
    public var onCellsReloaded: CellsChangedEvent?
    
    public override func responds(to aSelector: Selector) -> Bool {
        let usesAutoLayoutHeight = rowHeightMode == .automatic || rowHeightMode == .default
        
        if usesAutoLayoutHeight && aSelector == slHeightForRowAtIndexPath {
            return false
        }
        
        if let delegate = delegate where delegate.responds(to: aSelector) {
            return true
        }
        return super.responds(to: aSelector)
    }
    
    public override func forwardingTarget(for aSelector: Selector) -> AnyObject? {
        if let delegate = delegate where delegate.responds(to: aSelector) {
            return delegate
        }
        return super.forwardingTarget(for: aSelector)
    }
}
