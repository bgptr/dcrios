//  TransactionInputDetailCell.swift
//  Decred Wallet
//
// Copyright (c) 2018-2020 The Decred developers
// Use of this source code is governed by an ISC
// license that can be found in the LICENSE file.

import UIKit

class TransactionInputDetailCell: UITableViewCell {
    @IBOutlet weak var txAmountLabel: UILabel!
    @IBOutlet weak var txHashLabel: UILabel!

    func setup(_ input: TxInput) {
        self.txAmountLabel.text = Utils.getAttributedString(str: "\(input.dcrAmount.round(8))", siz: 16, TexthexColor: UIColor.appColors.darkBlue).string
            + " (\(input.accountName))"

        var hash = input.previousTransactionHash
        if hash == "0000000000000000000000000000000000000000000000000000000000000000" {
            hash = "Stakebase: 0000"
        }
        hash = "\(hash):\(input.previousTransactionIndex)"
        self.txHashLabel.text = hash
    }
}
