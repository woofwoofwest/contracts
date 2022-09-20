// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.0;

import "./interfaces/IEquipment.sol";
import "./interfaces/ITraits.sol";
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

contract EquipmentUpgrade is OwnableUpgradeable, PausableUpgradeable {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    event UpgradeEquipment(address indexed sender, IEquipment.sEquipment e);

    IEquipmentEnumerable public equipment;
    ITreasury public treasury;
    IVestingPool public pawVestingPool;
    IVestingPool public gemVestingPool;
    IRandomseeds public randomseeds;
    address public gem;
    address public paw;

    function initialize(
        address _equipment,
        address _treasury,
        address _pawVestingPool,
        address _gemVestingPool,
        address _paw,
        address _gem,
        address _randomseeds
    ) external initializer {
        require(_equipment != address(0));
        require(_treasury != address(0));
        require(_pawVestingPool != address(0));
        require(_gemVestingPool != address(0));
        require(_paw != address(0));
        require(_gem != address(0));
        require(_randomseeds != address(0));

        __Ownable_init();
        __Pausable_init();

        equipment = IEquipmentEnumerable(_equipment);
        treasury = ITreasury(_treasury);
        pawVestingPool = IVestingPool(_pawVestingPool);
        gemVestingPool = IVestingPool(_gemVestingPool);
        paw = _paw;
        gem = _gem;
        randomseeds = IRandomseeds(_randomseeds);

        _safeApprove(_gem, _treasury);
        _safeApprove(_paw, _treasury);
    }

    function pause() external onlyOwner whenNotPaused {
        _pause();
    }

    function unpause() external onlyOwner whenPaused {
        _unpause();
    }

    function upgrade(uint32 _tokenId) external whenNotPaused {
        require(tx.origin == _msgSender(), "Not EOA");
        require(equipment.ownerOf(_tokenId) == _msgSender(), "Not owner");
        IEquipment.sEquipment memory e = equipment.getTokenTraits(_tokenId);
        require(e.level < 10, "Reach the maximum level cap");
        IEquipmentConfig.sEquipmentLevelConfig memory curLevelConfig = equipment.getLevelConfig(e.eType, e.level);
        _upgradeCost(curLevelConfig.costToken, curLevelConfig.cost);
        e.level += 1;
        IEquipmentConfig.sEquipmentLevelConfig memory nextLevelConfig = equipment.getLevelConfig(e.eType, e.level);
        uint256[] memory seeds = randomseeds.multiRandomSeeds(block.difficulty + _tokenId, 3);
        e.hp = nextLevelConfig.hp[0];
        e.attack = nextLevelConfig.attack[0];
        e.hitRate = nextLevelConfig.hitRate[0];
        if (nextLevelConfig.hp[1] > nextLevelConfig.hp[0]) {
            e.hp += uint32(seeds[0] % (nextLevelConfig.hp[1] - nextLevelConfig.hp[0]));
        }
        if (nextLevelConfig.attack[1] > nextLevelConfig.attack[0]) {
            e.attack += uint32(seeds[1] % (nextLevelConfig.attack[1] - nextLevelConfig.attack[0]));
        }
        if (nextLevelConfig.hitRate[1] > nextLevelConfig.hitRate[0]) {
            e.hitRate += uint32(seeds[2] % (nextLevelConfig.hitRate[1] - nextLevelConfig.hitRate[0]));
        }
        equipment.updateTokenTraits(e);
        emit UpgradeEquipment(_msgSender(), e);
    }

    function _upgradeCost(uint8 _costToken, uint256 _cost) internal {
        if (_cost == 0) {
            return;
        }

        if (_costToken == 0) {
            uint256 bal1 = IERC20(paw).balanceOf(_msgSender());
            uint256 bal2 = pawVestingPool.balanceOf(_msgSender());
            require(bal1 + bal2 >= _cost, "pawCost exceeds balance");
            if (bal2 >= _cost) {
                pawVestingPool.transferFrom(_msgSender(), address(this), _cost);
            } else {
                if (bal2  > 0) {
                    pawVestingPool.transferFrom(_msgSender(), address(this), bal2);
                }
                IERC20(paw).safeTransferFrom(_msgSender(), address(this), _cost);
            }
            treasury.deposit(paw, _cost);
        } else {
            uint256 bal1 = IERC20(gem).balanceOf(_msgSender());
            uint256 bal2 = gemVestingPool.balanceOf(_msgSender());
            require(bal1 + bal2 >= _cost, "gemCost exceeds balance");
            if (bal2 >= _cost) {
                gemVestingPool.transferFrom(_msgSender(), address(this), _cost);
            } else {
                if (bal2  > 0) {
                    gemVestingPool.transferFrom(_msgSender(), address(this), bal2);
                }
                IERC20(gem).safeTransferFrom(_msgSender(), address(this), _cost);
            }
            treasury.deposit(gem, _cost);
        }
    }

    function _safeApprove(address _token, address _spender) internal {
        if (_token != address(0) && IERC20(_token).allowance(address(this), _spender) == 0) {
            IERC20(_token).safeApprove(_spender, type(uint256).max);
        }
    }
}