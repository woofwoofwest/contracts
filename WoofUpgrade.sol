// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import "./interfaces/IWoofEnumerable.sol";
import "./interfaces/IWoofConfig.sol";
import "./library/SafeERC20.sol";
import "./library/SafeMath.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

interface ITreasury {
    function deposit(address _token, uint256 _amount) external;
}

interface IVestingPool {
    function balanceOf(address _user) external view returns(uint256);
    function transferFrom(address _from, address _to, uint256 _amount) external;
}

interface IRandomseeds {
    function randomseed(uint256 _seed) external view returns (uint256);
    function multiRandomSeeds(uint256 _seed, uint256 _count) external view returns (uint256[] memory);
}

contract WoofUpgrade is OwnableUpgradeable, PausableUpgradeable {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    event UpgradeWoof(address indexed sender, IWoof.WoofWoofWest w);
    event SyntheticWoof(address indexed sender, IWoof.WoofWoofWest w);

    IWoofEnumerable public woof;
    ITreasury public treasury;
    IVestingPool public pawVestingPool;
    IWoofConfig public config;
    IRandomseeds public randomseeds;
    address public gem;
    address public paw;

    function initialize(
        address _woof,
        address _treasury,
        address _pawVestingPool,
        address _gem,
        address _paw,
        address _config,
        address _randomseeds
    ) external initializer {
        require(_woof != address(0));
        require(_treasury != address(0));
        require(_pawVestingPool != address(0));
        require(_gem != address(0));
        require(_paw != address(0));
        require(_config != address(0));
        require(_randomseeds != address(0));

        __Ownable_init();
        __Pausable_init();

        woof = IWoofEnumerable(_woof);
        treasury = ITreasury(_treasury);
        pawVestingPool = IVestingPool(_pawVestingPool);
        config = IWoofConfig(_config);
        randomseeds = IRandomseeds(_randomseeds);
        gem = _gem;
        paw = _paw;

        _safeApprove(_gem, _treasury);
        _safeApprove(_paw, _treasury);
    }

    function pause() external onlyOwner whenNotPaused {
        _pause();
    }

    function unpause() external onlyOwner whenPaused {
        _unpause();
    }

    function upgrade(uint32 _tokenId, uint32[] memory _nftIds) external whenNotPaused {
        require(tx.origin == _msgSender(), "Not EOA");
        require(woof.ownerOf(_tokenId) == _msgSender(), "Not owner");
        for (uint32 i = 0; i < _nftIds.length; ++i) {
            require(woof.ownerOf(_nftIds[i]) == _msgSender(), "Not owner");
        }
        uint256 seed = randomseeds.randomseed(block.difficulty);
        (IWoof.WoofWoofWest memory w, IWoofConfig.LevelUpCost memory cost) = config.levelUpWoofWoofWest(_tokenId, seed);
        _cost(cost, _nftIds);
        woof.updateTokenTraits(w);
        emit UpgradeWoof(_msgSender(), w);
    }

    function synthetic(uint32 _tokenId, uint32[] memory _nftIds) external whenNotPaused {
        require(tx.origin == _msgSender(), "Not EOA");
        require(woof.ownerOf(_tokenId) == _msgSender(), "Not owner");
        for (uint32 i = 0; i < _nftIds.length; ++i) {
            require(woof.ownerOf(_nftIds[i]) == _msgSender(), "Not owner");
        }
        uint256 seed = randomseeds.randomseed(block.difficulty);
        (IWoof.WoofWoofWest memory w, IWoofConfig.LevelUpCost memory cost) = config.syntheticWoofWoofWest(_tokenId, seed);
        _cost(cost, _nftIds);
        woof.updateTokenTraits(w);
        emit SyntheticWoof(_msgSender(), w);
    }

    function _safeApprove(address _token, address _spender) internal {
        if (_token != address(0) && IERC20(_token).allowance(address(this), _spender) == 0) {
            IERC20(_token).safeApprove(_spender, type(uint256).max);
        }
    }

    function _cost(IWoofConfig.LevelUpCost memory _levelUpCost, uint32[] memory _nftIds) internal {
        if (_levelUpCost.pawCost > 0) {
            uint256 bal1 = IERC20(paw).balanceOf(_msgSender());
            uint256 bal2 = pawVestingPool.balanceOf(_msgSender());
            require(bal1 + bal2 >= _levelUpCost.pawCost, "pawCost exceeds balance");
            if (bal2 >= _levelUpCost.pawCost) {
                pawVestingPool.transferFrom(_msgSender(), address(this), _levelUpCost.pawCost);
            } else {
                if (bal2  > 0) {
                    pawVestingPool.transferFrom(_msgSender(), address(this), bal2);
                }
                IERC20(paw).safeTransferFrom(_msgSender(), address(this), _levelUpCost.pawCost - bal2);
            }
            treasury.deposit(paw, _levelUpCost.pawCost);
        }

        for (uint8 i = 0; i < 5; ++i) {
            if (_levelUpCost.nftCost[i] > 0) {
                uint8 count = 0;
                for (uint32 j = 0; j < _nftIds.length; ++j) {
                    IWoof.WoofWoofWest memory w = woof.getTokenTraits(_nftIds[j]);
                    if (w.quality == i) {
                        count += 1;
                        woof.burn(w.tokenId);
                    }
                    if (count == _levelUpCost.nftCost[i]) {
                        break;
                    }
                }
                require(count == _levelUpCost.nftCost[i], "Not enough consumption nfts");
            }
        }
    }
}