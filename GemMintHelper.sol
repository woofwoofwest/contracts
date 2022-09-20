// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import "./library/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

interface IGem {
     function mint(address account_, uint256 amount_) external;
     function MAX_SUPPLY() external view returns(uint256);
}

contract GemMintHelper is OwnableUpgradeable, PausableUpgradeable {
    IGem public gem;
    bool public preMined;
    mapping (address=>bool) internal _vaultControllers;

    function initialize(
        address _gem
    ) external initializer {
        require(_gem != address(0));

        __Ownable_init();
        __Pausable_init();

        gem = IGem(_gem);
        _vaultControllers[msg.sender] = true;
        preMined = false;
    }

    function preMint(address[] memory _accounts, uint8[] memory _shares) external onlyOwner {
        require(preMined == false);
        require(_accounts.length == _shares.length);
        uint256 maxAmount = gem.MAX_SUPPLY();
        for (uint8 i = 0; i < _accounts.length; ++i) {
            require(_shares[i] < 50);
            uint256 amount = maxAmount * _shares[i] / 100;
            gem.mint(_accounts[i], amount);
        }
        preMined = true;
    }

    function setVault(address _vault, bool _enable) external onlyOwner returns ( bool ) {
        _vaultControllers[_vault] = _enable;
        return true;
    }

    function vault(address _vault) public view returns ( bool ) {
        return _vaultControllers[_vault];
    }

    modifier onlyVault() {
        require( _vaultControllers[msg.sender] == true, "VaultOwned: caller is not the Vault" );
        _;
    }

    function pause() external onlyOwner whenNotPaused {
        _pause();
    }

    function unpause() external onlyOwner whenPaused {
        _unpause();
    }

    function mint(address _account, uint256 _amount) external onlyVault whenNotPaused {
        gem.mint(_account, _amount);
    }
}