//
//  WalletsViewController.swift
//  Decred Wallet
//
// Copyright (c) 2020 The Decred developers
// Use of this source code is governed by an ISC
// license that can be found in the LICENSE file.

import UIKit
import Dcrlibwallet

class WalletsViewController: UIViewController {
    @IBOutlet weak var walletsTableView: UITableView!
    
    var wallets = [Wallet]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.walletsTableView.hideEmptyAndExtraRows()
        self.walletsTableView.registerCellNib(WalletInfoTableViewCell.self)
        self.walletsTableView.dataSource = self
        self.walletsTableView.delegate = self
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.navigationBar.isHidden = true
        
        self.loadWallets()
    }
    
    func loadWallets() {
        self.wallets = WalletLoader.shared.wallets.map({ Wallet.init($0) })
        self.walletsTableView.reloadData()
    }
    
    // todo prolly hide this action if sync is ongoing as wallets cannot be added during ongoing sync
    @IBAction func addNewWalletTapped(_ sender: Any) {
        let alertController = UIAlertController(title: nil,
                                                message: LocalizedStrings.createOrImportWallet,
                                                preferredStyle: .actionSheet)
        
        alertController.addAction(UIAlertAction(title: LocalizedStrings.createNewWallet, style: .default, handler: { _ in
            if StartupPinOrPassword.pinOrPasswordIsSet() {
                self.verifyStartupSecurityCode(prompt: LocalizedStrings.confirmToCreateNewWallet,
                                               onVerifiedSuccess: self.createNewWallet)
            } else {
                self.createNewWallet()
            }
        }))
        
        alertController.addAction(UIAlertAction(title: LocalizedStrings.restoreExistingWallet, style: .default, handler: { _ in
            if StartupPinOrPassword.pinOrPasswordIsSet() {
                self.verifyStartupSecurityCode(prompt: LocalizedStrings.confirmToImportWallet,
                                               onVerifiedSuccess: self.goToRestoreWallet)
            } else {
                self.goToRestoreWallet()
            }
        }))
        
        alertController.addAction(UIAlertAction(title: LocalizedStrings.cancel, style: .cancel, handler: nil))
        
        self.present(alertController, animated: true, completion: nil)
    }
    
    func verifyStartupSecurityCode(prompt: String, onVerifiedSuccess: @escaping () -> ()) {
        Security.startup()
            .with(prompt: prompt)
            .with(submitBtnText: LocalizedStrings.confirm)
            .requestCurrentCode(sender: self) { pinOrPassword, _, completion in
                
                do {
                    try WalletLoader.shared.multiWallet.verifyStartupPassphrase(pinOrPassword.utf8Bits)
                    completion?.dismissDialog()
                    onVerifiedSuccess()
                } catch let error {
                    if error.isInvalidPassphraseError {
                        completion?.displayError(errorMessage: StartupPinOrPassword.invalidSecurityCodeMessage())
                    } else {
                        completion?.displayError(errorMessage: error.localizedDescription)
                    }
                }
        }
    }
    
    func createNewWallet() {
        Security.spending(initialSecurityType: .password).requestNewCode(sender: self, isChangeAttempt: false) { pinOrPassword, type, completion in
            WalletLoader.shared.createWallet(spendingPinOrPassword: pinOrPassword, securityType: type) { error in
                if error == nil {
                    completion?.dismissDialog()
                    self.loadWallets()
                    Utils.showBanner(in: self.view, type: .success, text: LocalizedStrings.walletCreated)
                } else {
                    completion?.displayError(errorMessage: error!.localizedDescription)
                }
            }
        }
    }
    
    func goToRestoreWallet() {
        let restoreWalletVC = RestoreExistingWalletViewController.instantiate(from: .WalletSetup)
        restoreWalletVC.onWalletRestored = {
            self.loadWallets()
            Utils.showBanner(in: self.view, type: .success, text: LocalizedStrings.walletCreated)
        }
        self.navigationController?.pushViewController(restoreWalletVC, animated: true)
    }
}

extension WalletsViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.wallets.count
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let wallet = self.wallets[indexPath.row]
        var cellHeight = WalletInfoTableViewCell.walletInfoSectionHeight
        
        if !wallet.isSeedBackedUp {
            cellHeight += WalletInfoTableViewCell.walletNotBackedUpLabelHeight
                + WalletInfoTableViewCell.seedBackupPromptHeight
        }
        
        if wallet.displayAccounts {
            cellHeight += (WalletInfoTableViewCell.accountCellHeight * CGFloat(wallet.accounts.count))
                + WalletInfoTableViewCell.addNewAccountButtonHeight
        }
        
        return cellHeight
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let walletViewCell = tableView.dequeueReusableCell(withIdentifier: "WalletInfoTableViewCell") as! WalletInfoTableViewCell
        walletViewCell.wallet = self.wallets[indexPath.row]
        walletViewCell.delegate = self
        return walletViewCell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.wallets[indexPath.row].toggleAccountsDisplay()
        tableView.reloadData()
    }
}

extension WalletsViewController: WalletInfoTableViewCellDelegate {
    func walletSeedBackedUp() {
        self.loadWallets()
    }
    
    func showWalletMenu(walletName: String, walletID: Int) {
        let prompt = String(format: "%@ (%@)", LocalizedStrings.wallet, walletName)
        let walletMenu = UIAlertController(title: nil, message: prompt, preferredStyle: .actionSheet)
        
        walletMenu.addAction(UIAlertAction(title: LocalizedStrings.signMessage, style: .default, handler: { _ in
            
        }))
        
        walletMenu.addAction(UIAlertAction(title: LocalizedStrings.verifyMessage, style: .default, handler: { _ in
            
        }))
        
        walletMenu.addAction(UIAlertAction(title: LocalizedStrings.viewProperty, style: .default, handler: { _ in
            
        }))
        
        walletMenu.addAction(UIAlertAction(title: LocalizedStrings.rename, style: .default, handler: { _ in
            self.renameWallet(walletID: walletID)
        }))
        
        walletMenu.addAction(UIAlertAction(title: LocalizedStrings.settings, style: .default, handler: { _ in
            self.goToWalletSettingsPage(walletID: walletID)
        }))
        
        walletMenu.addAction(UIAlertAction(title: LocalizedStrings.cancel, style: .cancel, handler: nil))
        
        self.present(walletMenu, animated: true, completion: nil)
    }
    
    func addNewAccount(_ wallet: Wallet) {
        print("add new account to", wallet.name)
    }
    
    func showAccountDetailsDialog(_ account: DcrlibwalletAccount) {
        AccountDetailsViewController.showDetails(for: account, onAccountDetailsUpdated: self.refreshAccountDetails, sender: self)
    }

    func refreshAccountDetails() {
        self.wallets.forEach({ $0.reloadAccounts() })
        self.walletsTableView.reloadData()
    }
}

// extension to handle wallet menu options.
extension WalletsViewController {
    func renameWallet(walletID: Int) {
        SimpleTextInputDialog.show(sender: self,
                                   title: LocalizedStrings.renameWallet,
                                   placeholder: LocalizedStrings.walletName,
                                   submitButtonText: LocalizedStrings.rename) { newWalletName, dialogDelegate in
            
            do {
                try WalletLoader.shared.multiWallet.renameWallet(walletID, newName: newWalletName)
                dialogDelegate?.dismissDialog()
                self.loadWallets()
                Utils.showBanner(in: self.view, type: .success, text: LocalizedStrings.walletRenamed)
            } catch let error {
                dialogDelegate?.displayError(errorMessage: error.localizedDescription)
            }
        }
    }
    
    func goToWalletSettingsPage(walletID: Int) {
        guard let wallet = WalletLoader.shared.multiWallet.wallet(withID: walletID) else {
            return
        }
        
        let walletSettingsVC = WalletSettingsViewController.instantiate(from: .Wallets)
        walletSettingsVC.wallet = wallet
        self.navigationController?.pushViewController(walletSettingsVC, animated: true)
    }
}
