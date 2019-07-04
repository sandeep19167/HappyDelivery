//
//  ViewController.swift
//  HappyDelivery
//
//  Created by Sandeep Yadav on 26/06/19.
//  Copyright © 2019 Sandeep Yadav. All rights reserved.
//

import UIKit

class DeliveryListViewController: UIViewController {

    var tableView: UITableView!
    
    var refreshControl = UIRefreshControl()
    
    var animatedCell: [IndexPath] = []
    
    var deliveryLists: [DeliveryListModel] = []
    
    var bottomAcivityIndicator: UIActivityIndicatorView = UIActivityIndicatorView()
    
    var isNextPageApiCalled: Bool = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.setUpUI()
        
        // Do any additional setup after loading the view.
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
    }
    
    @objc func refresh(sender: AnyObject) {
        
        self.getDeliveryList(isToPullRefresh: true)
        
    }
    
    func setUpUI() {
        
        self.title = NavigationTitle().deliveryList
        
        tableView = UITableView()
        
        tableView.register(DeliveryListTableViewCell.self, forCellReuseIdentifier: "cell")
        
        refreshControl.addTarget(self, action: #selector(refresh(sender:)), for: UIControl.Event.valueChanged)
        
        if #available(iOS 10.0, *) {
            tableView.refreshControl = refreshControl
        } else {
            tableView.addSubview(refreshControl)
        }
        
        self.view.addSubview(tableView)
        self.view.addSubview(bottomAcivityIndicator)
        
        tableView.translatesAutoresizingMaskIntoConstraints = false
        bottomAcivityIndicator.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint(item: tableView as Any, attribute: NSLayoutConstraint.Attribute.top, relatedBy: NSLayoutConstraint.Relation.equal, toItem: self.view, attribute: NSLayoutConstraint.Attribute.top, multiplier: Constraint.Multiplier.one, constant: Constraint.Constant.zero).isActive = true
        
        NSLayoutConstraint(item: tableView as Any, attribute: NSLayoutConstraint.Attribute.leading, relatedBy: NSLayoutConstraint.Relation.equal, toItem: self.view, attribute: NSLayoutConstraint.Attribute.leading, multiplier: Constraint.Multiplier.one, constant: Constraint.Constant.zero).isActive = true
        
        NSLayoutConstraint(item: tableView as Any, attribute: NSLayoutConstraint.Attribute.trailing, relatedBy: NSLayoutConstraint.Relation.equal, toItem: self.view, attribute: NSLayoutConstraint.Attribute.trailing, multiplier: Constraint.Multiplier.one, constant: Constraint.Constant.zero).isActive = true
        
        NSLayoutConstraint(item: tableView as Any, attribute: NSLayoutConstraint.Attribute.bottom, relatedBy: NSLayoutConstraint.Relation.equal, toItem: self.view, attribute: NSLayoutConstraint.Attribute.bottom, multiplier: Constraint.Multiplier.one, constant: Constraint.Constant.zero).isActive = true
        
        NSLayoutConstraint(item: bottomAcivityIndicator, attribute: .centerX, relatedBy: NSLayoutConstraint.Relation.equal, toItem: self.view, attribute: .centerX, multiplier: Constraint.Multiplier.one, constant: Constraint.Constant.zero).isActive = true
        
        NSLayoutConstraint(item: bottomAcivityIndicator, attribute: .bottom, relatedBy: .equal, toItem: self.view, attribute: .bottomMargin, multiplier: Constraint.Multiplier.one, constant: Constraint.Constant.zero).isActive = true
        
        self.bottomAcivityIndicator.isHidden = true
        self.bottomAcivityIndicator.color = .black
        
        tableView.backgroundColor = .white
        tableView.separatorStyle = .none
        
        self.tableView.estimatedRowHeight = CGFloat(kTableViewDefaultHeight)
        self.tableView.rowHeight = UITableView.automaticDimension
        
        self.checkExistingDeliveryListData()
        
    }
    
    func checkExistingDeliveryListData() {
        
        self.deliveryLists = CoreDataHelper.shared.getDeliveryListData(offset: deliveryLists.count, limit: kListLimit)
        
        self.tableView.delegate = self
        self.tableView.dataSource = self
        
        if self.deliveryLists.count > 0 {
            
            self.tableView.reloadData()
            
        } else {
            
            self.getDeliveryList()
            
        }
        
    }
    
    func generateRequestModel(isToPullRefresh: Bool? = false) -> DeliveryListRequestModel {
        
        let requestModel = DeliveryListRequestModel.Builder()
            .offset(index: isToPullRefresh == false ? self.deliveryLists.count : 0)
            .limit(index: kListLimit)
            .build()
        
        return requestModel
        
    }

}

// MARK: - Api Request
extension DeliveryListViewController {
    
    func getDeliveryList(isToPullRefresh: Bool? = false) {
        
        let requestModel = self.generateRequestModel(isToPullRefresh: isToPullRefresh)
        
        if !(isToPullRefresh ?? true) {
            
            Indicator.shared.showActivityIndicatory(uiView: self.view)
            
        }
        
        WebServices.shared.requestForGetType(url: requestModel.deliveryListUrl(), parameters: requestModel.requestBody as [NSString: NSObject], {[weak self](response) in
            
            Indicator.shared.hideAcivityIndicator()
            
            if isToPullRefresh ?? false {
                
                self?.refreshControl.endRefreshing()
                
                if (response as? NSArray)?.count ?? 0 > 0 {
                    
                    self?.deliveryLists.removeAll()
                    
                    CoreDataHelper.shared.deleteAllRecords()
                    
                }
                
            }
            
            self?.deliveryLists = ModelConversion.arrayModelFromDictionary(array: response as? NSArray ?? [])
            
            self?.tableView.reloadData()
            
            CoreDataHelper.shared.save(deliveryList: self?.deliveryLists ?? [])
            
        }, {[weak self](error)  in
            
            Indicator.shared.hideAcivityIndicator()
            
            DispatchQueue.main.async {[weak self] in
                self?.refreshControl.endRefreshing()
                self?.tableView.reloadData()
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: {[weak self] in
                
                self?.showAlertWithCancelButton(error.localizedDescription, AlertKey.retry, {[weak self] in
                    self?.getDeliveryList(isToPullRefresh: false)
                })
                
            })
            
        })
        
    }
    
    func getNextPageData() {
        
        let fetchedData = CoreDataHelper.shared.getDeliveryListData(offset: self.deliveryLists.count, limit: kListLimit)
        
        if fetchedData.count > 0 {
        
            self.deliveryLists += fetchedData
            
            DispatchQueue.main.async {[weak self] in
                
                self?.tableView.reloadData()
                
            }
            
        } else {
            
            DispatchQueue.main.async {[weak self] in
                self?.isNextPageApiCalled = true
                self?.getDeliveryListNextPageData()
            }
            
        }
        
    }
    
    func getDeliveryListNextPageData() {
        
        let requestModel = self.generateRequestModel(isToPullRefresh: false)
        
        bottomAcivityIndicator.isHidden = false
        bottomAcivityIndicator.startAnimating()
        
        WebServices.shared.requestForGetType(url: requestModel.deliveryListUrl(), parameters: requestModel.requestBody as [NSString: NSObject], {[weak self](response) in
            
            self?.bottomAcivityIndicator.isHidden = true
            self?.bottomAcivityIndicator.stopAnimating()
            
            if let resultData = response as? NSArray, resultData.count != 0 {
                
                let deliveryListsItem = ModelConversion.arrayModelFromDictionary(array: resultData)
                
                self?.deliveryLists += deliveryListsItem
                
                self?.tableView.reloadData()
                
                CoreDataHelper.shared.save(deliveryList: deliveryListsItem)
                
            }
            
            self?.isNextPageApiCalled = false
            
        }, {[weak self](error) in
            
            self?.bottomAcivityIndicator.isHidden = true
            self?.bottomAcivityIndicator.stopAnimating()
            
            self?.showAlert(error.localizedDescription, nil)
            
            self?.isNextPageApiCalled = false
            
        })
        
    }
    
}

// MARK: - Table View Delegate, DataSource
extension DeliveryListViewController: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.deliveryLists.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath) as! DeliveryListTableViewCell
        
        cell.selectionStyle = .none
        
        cell.configCell(self.deliveryLists[indexPath.row])
        
        return cell
        
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        let vc = DeliveryDetailViewController(model: self.deliveryLists[indexPath.row])
        
        self.navigationController?.pushViewController(vc, animated: true)
        
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        
        if !animatedCell.contains(indexPath) {
            
            animatedCell.append(indexPath)
            
            cell.transform = CGAffineTransform(scaleX: 0.2, y: 0.2)
            
            UIView.animate(withDuration: 0.4) {
                cell.transform = CGAffineTransform.identity
            }
            
        }
        
        if indexPath.row == self.deliveryLists.count - 1 && isNextPageApiCalled == false {
            
            self.getNextPageData()
            
        }
        
    }
    
}
