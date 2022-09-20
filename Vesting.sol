// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import "./library/SafeERC20.sol";
import "./library/SafeMath.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract Vesting is OwnableUpgradeable {
    struct AccountInfo {
        uint256 initReleaseAmount;
        uint256 perReleaseAmount;
        uint256 totalReleaseAmount;
        uint256 accReleaseAmount;
    }

    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    mapping(address => bool) public authControllers;

    address public vestingToken;
    uint256 public startTime;
    uint256 public claimTime;
    uint256 public initReleaseShares;
    uint256 public releaseTimes;
    uint256 public accReleaseTimes;

    mapping(address=>AccountInfo) public vestingAccountsInfo;
    address[] public vestingAccounts;
    uint256 public unit;

    function initialize(
        address _vestingToken,
        uint256 _initReleaseShares,
        uint256 _releaseTimes
    ) external initializer {
        require(_vestingToken != address(0));
        require(_initReleaseShares < 100);
        require(_releaseTimes <= 24);
        __Ownable_init();
        vestingToken = _vestingToken;
        initReleaseShares = _initReleaseShares;
        releaseTimes = _releaseTimes;
        authControllers[_msgSender()] = true;
        unit = 30 days;
    }

    function setUnit(uint256 _unit) external onlyOwner {
        require(_unit > 0);
        unit = _unit;
    }


    function setAuthControllers(address _controller, bool _enable) external onlyOwner {
        authControllers[_controller] = _enable;
    }

    function replaceAccount(address _oldAccount, address _newAccount) public onlyOwner {
        require(_oldAccount != address(0));
        require(_newAccount != address(0));
        require(vestingAccountsInfo[_oldAccount].totalReleaseAmount != 0);
        vestingAccountsInfo[_newAccount] = vestingAccountsInfo[_oldAccount];
        deleteAccount(_oldAccount);
        vestingAccounts.push(_newAccount);
    }

    function deleteAccount(address _account) public onlyOwner {
        for (uint256 i = 0; i < vestingAccounts.length; ++i) {
            if (vestingAccounts[i] == _account) {
                vestingAccounts[i] = vestingAccounts[vestingAccounts.length - 1];
                vestingAccounts.pop();
                break;
            }
        }
        delete vestingAccountsInfo[_account];
    }

    function initRelease(uint256 _relay, address[] memory _accounts, uint256[] memory _amounts) external onlyOwner {
        require(startTime == 0, "0");
        _initVestingAccounts(_accounts, _amounts);
        startTime = block.timestamp + _relay * unit;
        claimTime = startTime;
        if (initReleaseShares > 0) {
            for (uint256 i = 0; i < _accounts.length; ++i) {
                address account = _accounts[i];
                AccountInfo memory info = vestingAccountsInfo[account];
                IERC20(vestingToken).transfer(account, info.initReleaseAmount);
                info.accReleaseAmount += info.initReleaseAmount;
                vestingAccountsInfo[account] = info;
            }
        }
    }

    function claim() external {
        require(authControllers[_msgSender()] == true, "0");
        require(startTime > 0, "1");
        require(claimTime <= block.timestamp, "2");
        require(accReleaseTimes < releaseTimes, "3");

        uint256 times = (block.timestamp - claimTime) / unit + 1;
        if (times + accReleaseTimes >= releaseTimes) {
            times = releaseTimes - accReleaseTimes;
        }

        for (uint256 i = 0; i < vestingAccounts.length; ++i) {
            address account = vestingAccounts[i];
            AccountInfo memory info = vestingAccountsInfo[account];
            uint256 amount = times * info.perReleaseAmount;
            IERC20(vestingToken).transfer(account, amount);
            info.accReleaseAmount += amount;
            require(info.accReleaseAmount <= info.totalReleaseAmount);
            vestingAccountsInfo[account] = info;
        }

        accReleaseTimes += times;
        claimTime = startTime + accReleaseTimes * unit;
    }

    function balanceOf(address _token) public view returns(uint256) {
        return IERC20(_token).balanceOf(address(this));
    }

    function _initVestingAccounts(address[] memory _accounts, uint256[] memory _amounts) private {
        require(_accounts.length == _amounts.length, "1");
        require(vestingAccounts.length == 0, "2");
        uint256 totalAmount = 0;
        for (uint256 i = 0; i < _accounts.length; ++i) {
            address account = _accounts[i];
            uint256 amount = _amounts[i] * 1 ether;
            vestingAccounts.push(account);
            AccountInfo memory info;
            info.initReleaseAmount = amount * initReleaseShares / 100;
            info.perReleaseAmount = (amount - info.initReleaseAmount) / releaseTimes;
            info.totalReleaseAmount = amount;
            vestingAccountsInfo[account] = info;
            totalAmount += amount;
        }

        require(totalAmount <= balanceOf(vestingToken), "3");
    }
}