//
//  ViewController.swift
//  SlideVC
//
//  Created by Asaf Baibekov on 7.8.2016.
//  Copyright © 2016 AasfB. All rights reserved.
//

import UIKit

public enum ButtonBarItemSpec<CellType: UICollectionViewCell> {
    case nibFile(nibName: String, bundle: Bundle?, width:((IndicatorInfo)-> CGFloat))
    case cellClass(width:((IndicatorInfo)-> CGFloat))
    public var weight: ((IndicatorInfo) -> CGFloat) {
        switch self {
        case .cellClass(let widthCallback):
            return widthCallback
        case .nibFile(_, _, let widthCallback):
            return widthCallback
        }
    }
}

public struct ButtonBarPagerTabStripSettings {
    public struct Style {
        public var buttonBarBackgroundColor: UIColor?
        @available(*, deprecated: 4.0.2) public var buttonBarMinimumInteritemSpacing: CGFloat? = 0
        public var buttonBarMinimumLineSpacing: CGFloat?
        public var buttonBarLeftContentInset: CGFloat?
        public var buttonBarRightContentInset: CGFloat?

        public var selectedBarBackgroundColor = UIColor.black
        public var selectedBarHeight: CGFloat = 5
        
        public var buttonBarItemBackgroundColor: UIColor?
        public var buttonBarItemFont = UIFont.systemFont(ofSize: 18)
        public var buttonBarItemLeftRightMargin: CGFloat = 8
        public var buttonBarItemTitleColor: UIColor?
        public var buttonBarItemsShouldFillAvailiableWidth = true
       
        // only used if button bar is created programaticaly and not using storyboards or nib files
        public var buttonBarHeight: CGFloat?
    }
    
    public var style = Style()
}

extension ButtonBarPagerTabStripViewController: UICollectionViewDelegateFlowLayout {
    public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        guard let cellWidthValue = cachedCellWidths?[indexPath.row] else {
            fatalError("cachedCellWidths for \(indexPath.row) must not be nil")
        }
        return CGSize(width: cellWidthValue, height: collectionView.frame.size.height)
    }
    
    public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard indexPath.item != currentIndex else { return }
        
        buttonBarView.moveToIndex(indexPath.item, animated: true, swipeDirection: .none, pagerScroll: .yes)
        shouldUpdateButtonBarView = false
        
        let oldCell = buttonBarView.cellForItem(at: IndexPath(item: currentIndex, section: 0)) as? ButtonBarViewCell
        let newCell = buttonBarView.cellForItem(at: IndexPath(item: indexPath.item, section: 0)) as? ButtonBarViewCell
        if pagerBehaviour.isProgressiveIndicator {
            if let changeCurrentIndexProgressive = changeCurrentIndexProgressive {
                changeCurrentIndexProgressive(oldCell, newCell, 1, true, true)
            }
        }
        else {
            if let changeCurrentIndex = changeCurrentIndex {
                changeCurrentIndex(oldCell, newCell, true)
            }
        }
        moveToViewControllerAtIndex(indexPath.item)
    }
    
    
}

extension ButtonBarPagerTabStripViewController: UICollectionViewDataSource {
    
    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return viewControllers.count
    }
    
    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Cell", for: indexPath) as? ButtonBarViewCell else {
            fatalError("UICollectionViewCell should be or extend from ButtonBarViewCell")
        }
        let childController = viewControllers[indexPath.item] as! IndicatorInfoProvider
        let indicatorInfo = childController.indicatorInfoForPagerTabStrip(self)
        
        cell.label.text = indicatorInfo.title
        cell.label.font = settings.style.buttonBarItemFont 
        cell.label.textColor = settings.style.buttonBarItemTitleColor ?? cell.label.textColor
        cell.contentView.backgroundColor = settings.style.buttonBarItemBackgroundColor ?? cell.contentView.backgroundColor
        cell.backgroundColor = settings.style.buttonBarItemBackgroundColor ?? cell.backgroundColor
        if let image = indicatorInfo.image {
            cell.imageView.image = image
        }
        if let highlightedImage = indicatorInfo.highlightedImage {
            cell.imageView.highlightedImage = highlightedImage
        }
        
        configureCell(cell, indicatorInfo: indicatorInfo)
        
        if pagerBehaviour.isProgressiveIndicator {
            if let changeCurrentIndexProgressive = changeCurrentIndexProgressive {
                changeCurrentIndexProgressive(currentIndex == indexPath.item ? nil : cell, currentIndex == indexPath.item ? cell : nil, 1, true, false)
            }
        }
        else {
            if let changeCurrentIndex = changeCurrentIndex {
                changeCurrentIndex(currentIndex == indexPath.item ? nil : cell, currentIndex == indexPath.item ? cell : nil, false)
            }
        }
        return cell
    }
    
}


open class ButtonBarPagerTabStripViewController: PagerTabStripViewController, PagerTabStripDataSource, PagerTabStripIsProgressiveDelegate {
    
    open var settings = ButtonBarPagerTabStripSettings()
    
    lazy open var buttonBarItemSpec: ButtonBarItemSpec<ButtonBarViewCell> = .nibFile(nibName: "ButtonCell", bundle: Bundle(for: ButtonBarViewCell.self), width:{ [weak self] (childItemInfo) -> CGFloat in
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = self?.settings.style.buttonBarItemFont
        label.text = childItemInfo.title
        let labelSize = label.intrinsicContentSize
        return labelSize.width + (self?.settings.style.buttonBarItemLeftRightMargin ?? 8) * 2
    })
    
    open var changeCurrentIndex: ((_ oldCell: ButtonBarViewCell?, _ newCell: ButtonBarViewCell?, _ animated: Bool) -> Void)?
    open var changeCurrentIndexProgressive: ((_ oldCell: ButtonBarViewCell?, _ newCell: ButtonBarViewCell?, _ progressPercentage: CGFloat, _ changeCurrentIndex: Bool, _ animated: Bool) -> Void)?
    
    @IBOutlet open lazy var buttonBarView: ButtonBarView! = { [unowned self] in
        var flowLayout = UICollectionViewFlowLayout()
        flowLayout.scrollDirection = .horizontal
        let buttonBarHeight = self.settings.style.buttonBarHeight ?? 44
        let buttonBar = ButtonBarView(frame: CGRect(x: 0, y: 0, width: self.view.frame.size.width, height: buttonBarHeight), collectionViewLayout: flowLayout)
        buttonBar.backgroundColor = .orange
        buttonBar.selectedBar.backgroundColor = .black
        buttonBar.autoresizingMask = .flexibleWidth
        var newContainerViewFrame = self.containerView.frame
        newContainerViewFrame.origin.y = buttonBarHeight
        newContainerViewFrame.size.height = self.containerView.frame.size.height - (buttonBarHeight - self.containerView.frame.origin.y)
        self.containerView.frame = newContainerViewFrame
        return buttonBar
    }()
    
    lazy fileprivate var cachedCellWidths: [CGFloat]? = { [unowned self] in
        return self.calculateWidths()
    }()
    
    override public init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        delegate = self
        dataSource = self
    }

    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        delegate = self
        dataSource = self
    }
    
    open override func viewDidLoad() {
        super.viewDidLoad()
        
        if buttonBarView.superview == nil {
            view.addSubview(buttonBarView)
        }
        if buttonBarView.delegate == nil {
            buttonBarView.delegate = self
        }
        if buttonBarView.dataSource == nil {
            buttonBarView.dataSource = self
        }
        buttonBarView.scrollsToTop = false
        let flowLayout = buttonBarView.collectionViewLayout as! UICollectionViewFlowLayout
        flowLayout.scrollDirection = .horizontal
        flowLayout.minimumInteritemSpacing = 0
        flowLayout.minimumLineSpacing = settings.style.buttonBarMinimumLineSpacing ?? flowLayout.minimumLineSpacing
        let sectionInset = flowLayout.sectionInset
        flowLayout.sectionInset = UIEdgeInsetsMake(sectionInset.top, self.settings.style.buttonBarLeftContentInset ?? sectionInset.left, sectionInset.bottom, self.settings.style.buttonBarRightContentInset ?? sectionInset.right)

        buttonBarView.showsHorizontalScrollIndicator = false
        buttonBarView.backgroundColor = settings.style.buttonBarBackgroundColor ?? buttonBarView.backgroundColor
        buttonBarView.selectedBar.backgroundColor = settings.style.selectedBarBackgroundColor
        
        buttonBarView.selectedBarHeight = settings.style.selectedBarHeight
        // register button bar item cell
        switch buttonBarItemSpec {
        case .nibFile(let nibName, let bundle, _):
            buttonBarView.register(UINib(nibName: nibName, bundle: bundle), forCellWithReuseIdentifier:"Cell")
        case .cellClass:
            buttonBarView.register(ButtonBarViewCell.self, forCellWithReuseIdentifier:"Cell")
        }
        //-
    }
    
    open override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        buttonBarView.layoutIfNeeded()
    }
    
    open override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        guard isViewAppearing || isViewRotating else { return }
        
        // Force the UICollectionViewFlowLayout to get laid out again with the new size if
        // a) The view is appearing.  This ensures that
        //    collectionView:layout:sizeForItemAtIndexPath: is called for a second time
        //    when the view is shown and when the view *frame(s)* are actually set
        //    (we need the view frame's to have been set to work out the size's and on the
        //    first call to collectionView:layout:sizeForItemAtIndexPath: the view frame(s)
        //    aren't set correctly)
        // b) The view is rotating.  This ensures that
        //    collectionView:layout:sizeForItemAtIndexPath: is called again and can use the views
        //    *new* frame so that the buttonBarView cell's actually get resized correctly
        cachedCellWidths = calculateWidths()
        buttonBarView.collectionViewLayout.invalidateLayout()
        // When the view first appears or is rotated we also need to ensure that the barButtonView's
        // selectedBar is resized and its contentOffset/scroll is set correctly (the selected
        // tab/cell may end up either skewed or off screen after a rotation otherwise)
        buttonBarView.moveToIndex(currentIndex, animated: false, swipeDirection: .none, pagerScroll: .scrollOnlyIfOutOfScreen)
    }
    
    open override func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        super.scrollViewDidEndScrollingAnimation(scrollView)
        
        guard scrollView == containerView else { return }
        shouldUpdateButtonBarView = true
    }
    
    // MARK: - Public Methods
    
    open override func reloadPagerTabStripView() {
        super.reloadPagerTabStripView()
        guard isViewLoaded else { return }
        buttonBarView.reloadData()
        cachedCellWidths = calculateWidths()
        buttonBarView.moveToIndex(currentIndex, animated: false, swipeDirection: .none, pagerScroll: .yes)
    }
    
    open func calculateStretchedCellWidths(_ minimumCellWidths: [CGFloat], suggestedStretchedCellWidth: CGFloat, previousNumberOfLargeCells: Int) -> CGFloat {
        var numberOfLargeCells = 0
        var totalWidthOfLargeCells: CGFloat = 0
        
        for minimumCellWidthValue in minimumCellWidths where minimumCellWidthValue > suggestedStretchedCellWidth {
            totalWidthOfLargeCells += minimumCellWidthValue
            numberOfLargeCells += 1
        }
        
        guard numberOfLargeCells > previousNumberOfLargeCells else { return suggestedStretchedCellWidth }
        
        let flowLayout = buttonBarView.collectionViewLayout as! UICollectionViewFlowLayout
        let collectionViewAvailiableWidth = buttonBarView.frame.size.width - flowLayout.sectionInset.left - flowLayout.sectionInset.right
        let numberOfCells = minimumCellWidths.count
        let cellSpacingTotal = CGFloat(numberOfCells - 1) * flowLayout.minimumLineSpacing
        
        let numberOfSmallCells = numberOfCells - numberOfLargeCells
        let newSuggestedStretchedCellWidth = (collectionViewAvailiableWidth - totalWidthOfLargeCells - cellSpacingTotal) / CGFloat(numberOfSmallCells)
        
        return calculateStretchedCellWidths(minimumCellWidths, suggestedStretchedCellWidth: newSuggestedStretchedCellWidth, previousNumberOfLargeCells: numberOfLargeCells)
    }
    
    open func pagerTabStripViewController(_ pagerTabStripViewController: PagerTabStripViewController, updateIndicatorFromIndex fromIndex: Int, toIndex: Int) {
        guard shouldUpdateButtonBarView else { return }
        buttonBarView.moveToIndex(toIndex, animated: true, swipeDirection: toIndex < fromIndex ? .right : .left, pagerScroll: .yes)
        
        if let changeCurrentIndex = changeCurrentIndex {
            let oldCell = buttonBarView.cellForItem(at: IndexPath(item: currentIndex != fromIndex ? fromIndex : toIndex, section: 0)) as? ButtonBarViewCell
            let newCell = buttonBarView.cellForItem(at: IndexPath(item: currentIndex, section: 0)) as? ButtonBarViewCell
            changeCurrentIndex(oldCell, newCell, true)
        }
    }
    
    open func pagerTabStripViewController(_ pagerTabStripViewController: PagerTabStripViewController, updateIndicatorFromIndex fromIndex: Int, toIndex: Int, withProgressPercentage progressPercentage: CGFloat, indexWasChanged: Bool) {
        guard shouldUpdateButtonBarView else { return }
        buttonBarView.moveFromIndex(fromIndex, toIndex: toIndex, progressPercentage: progressPercentage, pagerScroll: .yes)
        if let changeCurrentIndexProgressive = changeCurrentIndexProgressive {
            let oldCell = buttonBarView.cellForItem(at: IndexPath(item: currentIndex != fromIndex ? fromIndex : toIndex, section: 0)) as? ButtonBarViewCell
            let newCell = buttonBarView.cellForItem(at: IndexPath(item: currentIndex, section: 0)) as? ButtonBarViewCell
            changeCurrentIndexProgressive(oldCell, newCell, progressPercentage, indexWasChanged, true)
        }
    }
    
    open func configureCell(_ cell: ButtonBarViewCell, indicatorInfo: IndicatorInfo){
    }
    
    fileprivate func calculateWidths() -> [CGFloat] {
        let flowLayout = self.buttonBarView.collectionViewLayout as! UICollectionViewFlowLayout
        let numberOfCells = self.viewControllers.count
        
        var minimumCellWidths = [CGFloat]()
        var collectionViewContentWidth: CGFloat = 0
        
        for viewController in self.viewControllers {
            let childController = viewController as! IndicatorInfoProvider
            let indicatorInfo = childController.indicatorInfoForPagerTabStrip(self)
            switch buttonBarItemSpec {
            case .cellClass(let widthCallback):
                let width = widthCallback(indicatorInfo)
                minimumCellWidths.append(width)
                collectionViewContentWidth += width
            case .nibFile(_, _, let widthCallback):
                let width = widthCallback(indicatorInfo)
                minimumCellWidths.append(width)
                collectionViewContentWidth += width
            }
        }
        
        let cellSpacingTotal = CGFloat(numberOfCells - 1) * flowLayout.minimumLineSpacing
        collectionViewContentWidth += cellSpacingTotal
        
        let collectionViewAvailableVisibleWidth = self.buttonBarView.frame.size.width - flowLayout.sectionInset.left - flowLayout.sectionInset.right
        
        if !settings.style.buttonBarItemsShouldFillAvailiableWidth || collectionViewAvailableVisibleWidth < collectionViewContentWidth {
            return minimumCellWidths
        }
        else {
            let stretchedCellWidthIfAllEqual = (collectionViewAvailableVisibleWidth - cellSpacingTotal) / CGFloat(numberOfCells)
            let generalMinimumCellWidth = self.calculateStretchedCellWidths(minimumCellWidths, suggestedStretchedCellWidth: stretchedCellWidthIfAllEqual, previousNumberOfLargeCells: 0)
            var stretchedCellWidths = [CGFloat]()
            
            for minimumCellWidthValue in minimumCellWidths {
                let cellWidth = (minimumCellWidthValue > generalMinimumCellWidth) ? minimumCellWidthValue : generalMinimumCellWidth
                stretchedCellWidths.append(cellWidth)
            }
            
            return stretchedCellWidths
        }
    }
    
    fileprivate var shouldUpdateButtonBarView = true
    
}
