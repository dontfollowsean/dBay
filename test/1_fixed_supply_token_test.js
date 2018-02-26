var fixedSupplyToken = artifacts.require("./FixedSupplyToken.sol");

contract('MyToken', function (accounts) {
    it("First account should own all tokens", function () {
        var _totalSupply;
        var myTokenInstance;
        return fixedSupplyToken.deployed().then(function (instance) {
            myTokenInstance = instance;
            return myTokenInstance.totalSupply.call();
        }).then(function (totalSupply) {
            _totalSupply = totalSupply;
            return myTokenInstance.balanceOf(accounts[0]);
        }).then(function (balanceAccountOwner) {
            assert.equal(balanceAccountOwner.toNumber(), _totalSupply.toNumber(), "Total Amount of tokens is owned by owner");
        });
    });

    it("Second account should hace no tokens", function () {
        var myTokenInstance;
        return fixedSupplyToken.deployed().then(function (instance) {
            myTokenInstance = instance;
            return myTokenInstance.balanceOf(accounts[1]);
        }).then(function (balanceAccountOwner) {
            assert.equal(balanceAccountOwner.toNumber(), 0, "Total Amount of tokens is owned by some other address");
        });
    });

    it("Tokens should be transferred correctly", function () {
        var token;
        var accountOne = accounts[0];
        var accountTwo = accounts[1];
        var accountOneStartingBalance;
        var accountTwoStartingBalance;
        var accountOneEndingBalance;
        var accountTwoEndingBalance;

        var amount = 10;

        return fixedSupplyToken.deployed().then(function (instance) {
            token = instance;
            return token.balanceOf.call(accountOne);
        }).then(function (balance) {
            accountOneStartingBalance = balance.toNumber();
            return token.balanceOf.call(accountTwo);
        }).then(function (balance) {
            accountTwoStartingBalance = balance.toNumber();
            return token.transfer(accountTwo, amount, { from: accountOne });
        }).then(function () {
            return token.balanceOf.call(accountOne);
        }).then(function (balance) {
            accountOneEndingBalance = balance.toNumber();
            return token.balanceOf.call(accountTwo);
        }).then(function (balance) {
            accountTwoEndingBalance = balance.toNumber();

            assert.equal(accountOneEndingBalance, accountOneStartingBalance - amount, "Amount wasn't correctly taken from the sender");
            assert.equal(accountTwoEndingBalance, accountTwoStartingBalance + amount, "Amount wasn't correctly sent to the receiver");
        });
    });
});