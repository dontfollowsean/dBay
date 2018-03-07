//import jquery and bootstrap
import 'jquery';
import 'bootstrap-loader';
import "../stylesheets/app.css";
import { default as Web3 } from 'web3';
import { default as contract } from 'truffle-contract'
import exchange_artifacts from '../../build/contracts/Exchange.json'
import token_artifacts from '../../build/contracts/FixedSupplyToken.json'

var ExchangeContract = contract(exchange_artifacts);
var TokenContract = contract(token_artifacts);

var accounts;
var account;

window.App = {
  start: function () {
    var self = this;
    ExchangeContract.setProvider(web3.currentProvider);
    TokenContract.setProvider(web3.currentProvider);

    web3.eth.getAccounts(function (err, accs) {
      if (err != null) {
        alert("There was an error fetching your accounts.");
        return;
      }

      if (accs.length == 0) {
        // alert("Couldn't get any accounts. Make sure your Ethereum client is configured correctly.");
        return;
      }

      accounts = accs;
      account = accounts[0];
    });
  },

  setStatus: function (message) {
    var status = document.getElementById("status");
    status.innerHTML = message;
  },

  updateTokenBalance: function () {
    var tokenInstance;
    TokenContract.deployed().then(function (instance) {
      tokenInstance = instance;
      return tokenInstance.balanceOf.call(account);
    }).then(function (value) {
      var balanceElement = document.getElementById("tokenBalance");
      balanceElement.innerHTML = value.valueOf();
    }).catch(function (e) {
      console.log(e);
      App.setStatus("Error getting balance; see log.");
    });
  },

  watchTokenEvents: function () {
    var tokenInstance;
    TokenContract.deployed().then(function (instance) {
      tokenInstance = instance;
      tokenInstance.allEvents({}, { fromBlock: 0, toBlock: 'latest' }).watch(function (error, result) {
        var alertbox = document.createElement("div");
        alertbox.setAttribute("class", "alert alert-info  alert-dismissible");
        var closeBtn = document.createElement("button");
        closeBtn.setAttribute("type", "button");
        closeBtn.setAttribute("class", "close");
        closeBtn.setAttribute("data-dismiss", "alert");
        closeBtn.innerHTML = "<span>&times;</span>";
        alertbox.appendChild(closeBtn);

        var eventTitle = document.createElement("div");
        eventTitle.innerHTML = '<strong>New Event: ' + result.event + '</strong>';
        alertbox.appendChild(eventTitle);


        var argsBox = document.createElement("textarea");
        argsBox.setAttribute("class", "form-control");
        argsBox.innerText = JSON.stringify(result.args);
        alertbox.appendChild(argsBox);
        document.getElementById("tokenEvents").appendChild(alertbox);
        //document.getElementById("tokenEvents").innerHTML += '<div class="alert alert-info  alert-dismissible" role="alert"> <button type="button" class="close" data-dismiss="alert" aria-label="Close"><span aria-hidden="true">&times;</span></button><div></div><div>Args: '+JSON.stringify(result.args) + '</div></div>';

      });
    }).catch(function (e) {
      console.log(e);
      App.setStatus("Error getting balance; see log.");
    });
  },

  sendToken: function () {
    var self = this;

    var amount = parseInt(document.getElementById("inputAmountSendToken").value);
    var receiver = document.getElementById("inputBeneficiarySendToken").value;

    App.setStatus("Initiating transaction... (please wait)");

    var tokenInstance;
    return TokenContract.deployed().then(function (instance) {
      tokenInstance = instance;
      return tokenInstance.transfer(receiver, amount, { from: account });
    }).then(function () {
      App.setStatus("Transaction complete");
      App.updateTokenBalance();
    }).catch(function (e) {
      console.log(e);
      self.setStatus("Error sending coin; see log.");
    });
  },  

  printInfo: function () {
    ExchangeContract.deployed().then(function (instance) {
      var divAddress = document.createElement("div");
      divAddress.appendChild(document.createTextNode("Address Exchange: " + instance.address));
      divAddress.setAttribute("class", "alert alert-info");
      document.getElementById("importantInformation").appendChild(divAddress);
    });
    TokenContract.deployed().then(function (instance) {
      var divAddress = document.createElement("div");
      divAddress.appendChild(document.createTextNode("Address Token: " + instance.address));
      divAddress.setAttribute("class", "alert alert-info");
      document.getElementById("importantInformation").appendChild(divAddress);
    });

    web3.eth.getAccounts(function (err, accs) {
      web3.eth.getBalance(accs[0], function (err1, balance) {
        var divAddress = document.createElement("div");
        var div = document.createElement("div");
        div.appendChild(document.createTextNode("Active Account: " + accs[0]));
        var div2 = document.createElement("div");
        div2.appendChild(document.createTextNode("Balance in Ether: " + web3.fromWei(balance, "ether")));
        divAddress.appendChild(div);
        divAddress.appendChild(div2);
        divAddress.setAttribute("class", "alert alert-info");
        document.getElementById("importantInformation").appendChild(divAddress);
      });

    });  },

  allowanceToken: function () {
    var self = this;

    var amount = parseInt(document.getElementById("inputAmountAllowanceToken").value);
    var receiver = document.getElementById("inputBeneficiaryAllowanceToken").value;

    this.setStatus("Initiating transaction... (please wait)");

    var tokenInstance;
    return TokenContract.deployed().then(function (instance) {
      tokenInstance = instance;
      return tokenInstance.approve(receiver, amount, {from: account});
    }).then(function () {
      self.setStatus("Transaction complete!");
      App.updateTokenBalance();
    }).catch(function (e) {
      console.log(e);
      self.setStatus("Error sending coin; see log.");
    });;

  },

  addTokenToExchange: function () {
    var nameOfToken = document.getElementById("inputNameTokenAddExchange").value;
    var addressOfToken = document.getElementById("inputAddressTokenAddExchange").value;
    ExchangeContract.deployed().then(function (instance) {
      return instance.addToken(nameOfToken, addressOfToken, { from: account });
    }).then(function (txResult) {
      console.log(txResult);
      App.setStatus("Token added");
    }).catch(function (e) {
      console.log(e);
      App.setStatus("Error getting balance; see log.");
    });
  },

  initManageToken: function () {
    App.updateTokenBalance();
    App.watchTokenEvents();
    App.printInfo();
  },

  refreshBalance: function () {
    //TODO right now only works with FixedSupplyToken. should be updated to support tokens dynamically
    var self = this;

    var exchangeInstance;
    ExchangeContract.deployed().then(function (instance) {
      exchangeInstance = instance;
      return exchangeInstance.getBalance("FIXED");
    }).then(function (value) {
      var balanceElement = document.getElementById("balanceTokenInExchange");
      balanceElement.innerHTML = value.toNumber();
      return exchangeInstance.getEthBalanceInWei();
    }).then(function (value) {
      var balanceElement = document.getElementById("balanceEtherInExchange");
      balanceElement.innerHTML = web3.fromWei(value, "ether");
    }).catch(function (e) {
      console.log(e);
      self.setStatus("Error getting balance; see log.");
    });
  },

  initExchange: function () {
    // TODO line 190 gives invalid JSON RPC response
    // App.refreshBalance();
    App.watchExchangeEvents();
    App.printInfo();
  },
};

window.addEventListener('load', function () {
  // Checking if Web3 has been injected by the browser (Mist/MetaMask)
  if (typeof web3 !== 'undefined') {
    console.warn("Using web3 detected from external source.")
    window.web3 = new Web3(web3.currentProvider);
  } else {
    console.warn("No web3 detected. Falling back to http://localhost:8545. ");
    window.web3 = new Web3(new Web3.providers.HttpProvider("http://localhost:8545"));
  }

  App.start();
});
