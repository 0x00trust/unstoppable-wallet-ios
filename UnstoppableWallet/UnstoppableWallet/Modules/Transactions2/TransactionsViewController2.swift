import UIKit
import SnapKit
import ActionSheet
import ThemeKit
import HUD
import ComponentKit
import CurrencyKit
import RxSwift

class TransactionsViewController2: ThemeViewController {
    private let disposeBag = DisposeBag()
    private let viewModel: TransactionsViewModel
    
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let emptyLabel = UILabel()
    private let typeFiltersView = CoinFiltersView()
    private let coinFiltersView = CoinFiltersView()
    private let syncSpinner = HUDActivityView.create(with: .medium24)
    
    private var sections = [Section]()
    
    init(viewModel: TransactionsViewModel) {
        self.viewModel = viewModel
        
        super.init()
        
        tabBarItem = UITabBarItem(title: "transactions.tab_bar_item".localized, image: UIImage(named: "filled_transaction_2n_24"), tag: 0)
        navigationItem.largeTitleDisplayMode = .never
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "transactions.title".localized
        
        view.addSubview(tableView)
        tableView.backgroundColor = .clear
        tableView.snp.makeConstraints { maker in
            maker.top.equalToSuperview().offset(130)
            maker.leading.trailing.bottom.equalToSuperview()
        }
        tableView.dataSource = self
        tableView.delegate = self
        tableView.separatorStyle = .none
        tableView.backgroundColor = .clear
        tableView.tableFooterView = UIView(frame: .zero)
        tableView.contentInset = UIEdgeInsets(top: CoinFiltersView.height, left: 0, bottom: 0, right: 0)
        tableView.scrollIndicatorInsets = tableView.contentInset
        
        tableView.registerCell(forClass: H23Cell.self)
        tableView.registerHeaderFooter(forClass: TransactionDateHeaderView.self)
        tableView.estimatedRowHeight = 0
        tableView.delaysContentTouches = false

        view.addSubview(typeFiltersView)
        typeFiltersView.snp.makeConstraints { maker in
            maker.leading.trailing.equalToSuperview()
            maker.top.equalTo(view.safeAreaLayoutGuide)
            maker.height.equalTo(CoinFiltersView.height)
        }

        typeFiltersView.onSelect = { [weak self] index in
            self?.viewModel.typeFilterSelected(index: index)
        }
        typeFiltersView.onDeselect = { [weak self] index in
            self?.viewModel.typeFilterSelected(index: 0)
        }
        typeFiltersView.reload(filters: viewModel.typeFilters)

        view.addSubview(coinFiltersView)
        coinFiltersView.snp.makeConstraints { maker in
            maker.leading.trailing.equalToSuperview()
            maker.top.equalTo(typeFiltersView.snp.bottom)
            maker.height.equalTo(CoinFiltersView.height)
        }

        coinFiltersView.onSelect = { [weak self] index in
            self?.viewModel.coinFilterSelected(index: index)
        }
        coinFiltersView.onDeselect = { [weak self] index in
            self?.viewModel.coinFilterSelected(index: nil)
        }

        view.addSubview(emptyLabel)
        emptyLabel.snp.makeConstraints { maker in
            maker.centerY.equalToSuperview()
            maker.leading.equalToSuperview().offset(50)
            maker.trailing.equalToSuperview().offset(-50)
        }
        
        emptyLabel.text = "transactions.empty_text".localized
        emptyLabel.numberOfLines = 0
        emptyLabel.font = .systemFont(ofSize: 14)
        emptyLabel.textColor = .themeGray
        emptyLabel.textAlignment = .center
        
        let holder = UIView(frame: CGRect(x: 0, y: 0, width: 20, height: 20))
        holder.addSubview(syncSpinner)
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: holder)

        subscribe(disposeBag, viewModel.viewItemsDriver) { [weak self] sections in self?.show(sections: sections) }
        subscribe(disposeBag, viewModel.updatedViewItemSignal) { [weak self] (sectionIndex, rowIndex, item) in self?.update(sectionIndex: sectionIndex, rowIndex: rowIndex, item: item) }
        subscribe(disposeBag, viewModel.coinFiltersDriver) { [weak self] coinFilters in self?.show(filters: coinFilters) }
        subscribe(disposeBag, viewModel.viewStatusDriver) { [weak self] status in self?.show(status: status) }

        tableView.reloadData()
    }

    private func itemClicked(item: TransactionsModule2.ViewItem) {
        if let item = viewModel.transactionItem(uid: item.uid) {
            guard let module = TransactionInfoModule.instance(transactionItem: item) else {
                return
            }

            present(ThemeNavigationController(rootViewController: module), animated: true)
        }
    }

    private func update(sectionIndex: Int, rowIndex: Int, item: TransactionsModule2.ViewItem) {
        DispatchQueue.main.async {
            self.sections[sectionIndex].viewItems[rowIndex] = item

            let indexPath = IndexPath(row: rowIndex, section: sectionIndex)
            if let cell = self.tableView.cellForRow(at: indexPath) as? H23Cell {
                self.bind(item: item, cell: cell)
            }
        }
    }

    private func bind(item: TransactionsModule2.ViewItem, cell: H23Cell) {
        viewModel.willShow(uid: item.uid)

        cell.leftImage = UIImage(named: item.typeImage.imageName)?.withRenderingMode(.alwaysTemplate)
        cell.leftImageTintColor = item.typeImage.color
        cell.set(spinnerProgress: item.progress)

        cell.topText = item.title
        cell.topTextColor = .themeOz
        cell.bottomText = item.subTitle

        cell.valueTopText = item.primaryValue?.value
        cell.valueTopTextColor = item.primaryValue?.color ?? .themeGray
        cell.valueBottomText = item.secondaryValue?.value
        cell.valueBottomTextColor = item.secondaryValue?.color ?? .themeGray

        if item.sentToSelf {
            cell.valueLeftIconImage = UIImage(named: "arrow_medium_main_down_left_20")?.withRenderingMode(.alwaysTemplate)
            cell.valueLeftIconTinColor = .themeRemus
        } else {
            cell.valueLeftIconImage = nil
        }

        if let locked = item.locked {
            cell.valueRightIconImage = locked ? UIImage(named: "lock_20")?.withRenderingMode(.alwaysTemplate) : UIImage(named: "unlock_20")?.withRenderingMode(.alwaysTemplate)
            cell.valueRightIconTinColor = .themeGray
        } else {
            cell.valueRightIconImage = nil
        }
    }

    private func bind(itemAt indexPath: IndexPath, to cell: UITableViewCell?) {
        let item = sections[indexPath.section].viewItems[indexPath.row]
        
        if let cell = cell as? H23Cell {
            cell.set(backgroundStyle: .transparent, isFirst: indexPath.row != 0, isLast: true)
            bind(item: item, cell: cell)
        }
        
        if indexPath.section == tableView.numberOfSections - 1,
           indexPath.row >= self.tableView(tableView, numberOfRowsInSection: indexPath.section) - 1 {
            viewModel.bottomReached()
        }
    }

    private func show(sections: [Section]) {
        DispatchQueue.main.async { [weak self] in
            self?.sections = sections
            self?.tableView.reloadData()
        }
    }

    private func show(status: TransactionViewStatus) {
        syncSpinner.isHidden = !status.showProgress
        if status.showProgress {
            syncSpinner.startAnimating()
        } else {
            syncSpinner.stopAnimating()
        }
        
        emptyLabel.isHidden = !status.showMessage
    }

    private func show(filters: [String]) {
        coinFiltersView.reload(filters: filters)
    }

}

extension TransactionsViewController2: UITableViewDelegate, UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        sections.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        sections[section].viewItems.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        tableView.dequeueReusableCell(withIdentifier: String(describing: H23Cell.self), for: indexPath)
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        bind(itemAt: indexPath, to: cell)
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        itemClicked(item: sections[indexPath.section].viewItems[indexPath.row])
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        .heightDoubleLineCell
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        .heightSingleLineCell
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        tableView.dequeueReusableHeaderFooterView(withIdentifier: String(describing: TransactionDateHeaderView.self))
    }
    
    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        guard let view = view as? TransactionDateHeaderView else {
            return
        }
        
        view.text = sections[section].title
    }

}

extension TransactionsViewController2 {

    struct Section {
        let title: String
        var viewItems: [TransactionsModule2.ViewItem]
    }

}