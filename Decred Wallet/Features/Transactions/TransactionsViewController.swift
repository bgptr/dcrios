//
//  TransactionsViewController.swift
//  Decred Wallet
//
// Copyright (c) 2018-2020 The Decred developers
// Use of this source code is governed by an ISC
// license that can be found in the LICENSE file.

import UIKit
import Dcrlibwallet

class TransactionsViewController: UIViewController {
    @IBOutlet weak var headerTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var headerStackView: UIStackView!
    @IBOutlet weak var headerBottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var syncInProgressLabel: UILabel!
    @IBOutlet var transactionsTableView: UITableView!
    @IBOutlet var transactionFilterDropDown: DropMenuButton!
    @IBOutlet var transactionSorterDropDown: DropMenuButton!

    var noTxsLabel: UILabel {
        let noTxsLabel = UILabel(frame: self.transactionsTableView.frame)
        noTxsLabel.text = LocalizedStrings.noTransactions
        noTxsLabel.font = UIFont(name: "Source Sans Pro", size: 16)
        noTxsLabel.textColor = UIColor.appColors.lightBluishGray
        noTxsLabel.textAlignment = .center
        return noTxsLabel
    }

    var refreshControl: UIRefreshControl!
    var allTransactions = [Transaction]()
    let transactionFilters: [Int32] = [DcrlibwalletTxFilterAll,
                                       DcrlibwalletTxFilterSent,
                                       DcrlibwalletTxFilterReceived,
                                       DcrlibwalletTxFilterTransferred,
                                       DcrlibwalletTxFilterStaking,
                                       DcrlibwalletTxFilterCoinBase]
    let transactionSorters: [Bool] = [true, false]
    var filteredTransactions = [Transaction]()
    var maximumHeaderTopConstraint: CGFloat?

    override func viewDidLoad() {
        super.viewDidLoad()

        self.refreshControl = UIRefreshControl()
        self.refreshControl.tintColor = UIColor.lightGray
        self.refreshControl.addTarget(self,
                                      action: #selector(self.reloadTxsForCurrentFilter),
                                      for: UIControl.Event.valueChanged)

        self.transactionsTableView.addSubview(self.refreshControl)
        self.transactionsTableView.hideEmptyAndExtraRows()
        self.transactionsTableView.register(UINib(nibName: TransactionTableViewCell.identifier, bundle: nil),
                                            forCellReuseIdentifier: TransactionTableViewCell.identifier)
        // register for new transactions notifications
        try? WalletLoader.shared.multiWallet.add(self, uniqueIdentifier: "\(self)")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.navigationBar.isHidden = true

        self.syncInProgressLabel.isHidden = true
        self.transactionsTableView.isHidden = false
        self.loadAllTransactions()
    }

    func loadAllTransactions() {
        self.allTransactions.removeAll()
        self.refreshControl.showLoader(in: self.transactionsTableView)
        
        guard let txs = WalletLoader.shared.firstWallet?.transactionHistory(offset: 0), !txs.isEmpty else {
            self.transactionsTableView.backgroundView = self.noTxsLabel
            self.transactionsTableView.separatorStyle = .none
            self.refreshControl.endRefreshing()
            return
        }

        self.allTransactions = txs

        //setupTxSorter dropdown
        let sorterOptions = [LocalizedStrings.newest,
                             LocalizedStrings.oldest]
        self.transactionSorterDropDown.initMenu(sorterOptions) { [weak self] index, value in
            self?.reloadTxsForCurrentFilter()
        }

        //setupTxFilterAndDisplayAllTxs
        let filterOptions = [LocalizedStrings.all,
                             LocalizedStrings.sent,
                             LocalizedStrings.received,
                             LocalizedStrings.yourself,
                             LocalizedStrings.staking,
                             LocalizedStrings.coinbase]
        self.transactionFilterDropDown.initMenu(filterOptions) { [weak self] index, value in
            self?.reloadTxsForCurrentFilter()
        }
        
        self.transactionsTableView.backgroundView = nil
        self.transactionsTableView.separatorStyle = .singleLine

        self.transactionsTableView.reloadData()
        self.refreshControl.endRefreshing()
    }

    @objc func reloadTxsForCurrentFilter() {
        self.allTransactions.removeAll()
        self.refreshControl.showLoader(in: self.transactionsTableView)

        defer {
            self.transactionsTableView.reloadData()
            self.refreshControl.endRefreshing()
        }

        var currentFilterItem = DcrlibwalletTxFilterAll
        if self.transactionFilterDropDown.selectedItemIndex >= 0 && self.transactionFilters.count > self.transactionFilterDropDown.selectedItemIndex {
            currentFilterItem = self.transactionFilters[self.transactionFilterDropDown.selectedItemIndex]
        }

        var currentSorterType = true
        if self.transactionSorterDropDown.selectedItemIndex >= 0 && self.transactionSorters.count > self.transactionSorterDropDown.selectedItemIndex {
            currentSorterType = self.transactionSorters[self.transactionSorterDropDown.selectedItemIndex]
        }

        if let txs = WalletLoader.shared.firstWallet?.transactionHistory(offset: 0, count: 0, filter: currentFilterItem, newestFirst: currentSorterType) {
            self.allTransactions = txs
        }
    }
}

extension TransactionsViewController: DcrlibwalletTxAndBlockNotificationListenerProtocol {
    func onBlockAttached(_ walletID: Int, blockHeight: Int32) {
        // not relevant to this VC
    }

    func onTransaction(_ transaction: String?) {
        var tx = try! JSONDecoder().decode(Transaction.self, from: (transaction!.utf8Bits))

        if self.allTransactions.contains(where: { $0.hash == tx.hash }) {
            // duplicate notification, tx is already being displayed in table
            return
        }

        tx.animate = true
        self.allTransactions.insert(tx, at: 0)

        // Save hash for this tx as last viewed tx hash.
        Settings.setStringValue(tx.hash, for: DcrlibwalletLastTxHashConfigKey)

        DispatchQueue.main.async {
            self.reloadTxsForCurrentFilter()
        }
    }

    func onTransactionConfirmed(_ walletID: Int, hash: String?, blockHeight: Int32) {
        // all tx statuses will be updated when table rows are reloaded.
         DispatchQueue.main.async {
            self.transactionsTableView.reloadData()
        }
    }
}

extension TransactionsViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return (self.filteredTransactions.count > 0) ? self.filteredTransactions.count : self.allTransactions.count
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return TransactionTableViewCell.height()
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = self.transactionsTableView.dequeueReusableCell(withIdentifier: TransactionTableViewCell.identifier) as! TransactionTableViewCell

        var frame = cell.frame
        frame.size.width = self.transactionsTableView.frame.size.width
        cell.frame = frame

        if indexPath.row == 0 {
            cell.setRoundCorners(corners: [.topLeft, .topRight], radius: 14.0)
        } else if indexPath.row == allTransactions.count - 1 {
            cell.setRoundCorners(corners: [.bottomRight, .bottomLeft], radius: 14.0)
        } else {
            cell.setRoundCorners(corners: [.bottomRight, .bottomLeft, .topLeft, .topRight], radius: 0.0)
        }

        if self.filteredTransactions.isEmpty {
            cell.setData(allTransactions[indexPath.row])
            return cell
        }
        cell.setData(filteredTransactions[indexPath.row])
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let transactionDetailVC = TransactionDetailsViewController.instantiate(from: .TransactionDetails)

        if self.filteredTransactions.isEmpty {
            transactionDetailVC.transaction = self.allTransactions[indexPath.row]
        } else {
            transactionDetailVC.transaction = self.filteredTransactions[indexPath.row]
        }
        self.present(transactionDetailVC, animated: true)
    }
}

extension TransactionsViewController: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if self.maximumHeaderTopConstraint == nil {
            self.maximumHeaderTopConstraint = self.headerTopConstraint.constant
        }
        let minimumValue: CGFloat = -1 * (self.maximumHeaderTopConstraint! + self.headerStackView.frame.size.height +
            self.headerBottomConstraint.constant)
        self.headerTopConstraint.constant = min(self.maximumHeaderTopConstraint!, self.maximumHeaderTopConstraint! + max(minimumValue, -scrollView.contentOffset.y))
        self.headerStackView.alpha = headerTopConstraint.constant / self.maximumHeaderTopConstraint!
    }
}
