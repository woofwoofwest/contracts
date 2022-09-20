// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import "./interfaces/IWoofMineEnumerable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

struct Reward {
    uint32 lastRewardTime;
    uint256 pendingPaw;
    uint256 pendingGem;
}

interface IWoofMinePool  {
    function woofMineBrief(uint32 _tokenId) external view returns(IWoofMineEnumerable.WoofMineBrief memory);
    function checkLevelUp(uint32 _tokenId) external view returns(bool);
}

interface ILoot {
    function mineLootBrief(uint32 _tokenId) external view returns(uint32 totalLootCount, uint8 dailyLootCount);
}

contract WoofMineEnumerable is OwnableUpgradeable {
    IWoofMineEnumerable public woofMine;
    IWoofMinePool public woofMinePool;
    ILoot public loot;
    uint8 public maxPerAmount;

    function initialize(
        address _woofMine,
        address _woofMinePool,
        address _loot
    ) external initializer {
        require(_woofMine != address(0));
        require(_woofMinePool != address(0));
        require(_loot != address(0));
        __Ownable_init();
        woofMine = IWoofMineEnumerable(_woofMine);
        woofMinePool = IWoofMinePool(_woofMinePool);
        loot = ILoot(_loot);
        maxPerAmount = 10;
    }

    function setMaxPerAmount(uint8 _amount) external onlyOwner {
        require(_amount >= 4 && _amount <= 10);
        maxPerAmount = _amount;
    }

    function balanceOf(address _user) public view returns(uint256) {
        return woofMine.balanceOf(_user);
    }

    function totalSupply() public view returns(uint256) {
        return woofMine.totalSupply();
    }

    function getUserTokenTraits(address _user, uint256 _index, uint8 _len) public view returns(
        IWoofMineEnumerable.WoofMineBrief[] memory nfts, 
        uint8 len
    ) {
        require(_len <= maxPerAmount && _len != 0);
        nfts = new IWoofMineEnumerable.WoofMineBrief[](_len);
        len = 0;

        uint256 bal = woofMine.balanceOf(_user);
        if (bal == 0 || _index >= bal) {
            return (nfts, len);
        }

        for (uint8 i = 0; i < _len; ++i) {
            uint256 tokenId = woofMine.tokenOfOwnerByIndex(_user, _index);
            nfts[i] = woofMinePool.woofMineBrief(uint32(tokenId));
            (nfts[i].totalLootCount, nfts[i].dailyLootCount) = loot.mineLootBrief(uint32(tokenId));
            ++_index;
            ++len;
            if (_index >= bal) {
                return (nfts, len);
            }
        }
    }

    struct WoofMineBrief {
        IWoofMineEnumerable.WoofMineBrief woofMine;
        address owner;
    }

    function getTokenTraits(uint256 _index, uint8 _len) public view returns(
        WoofMineBrief[] memory nfts, 
        uint8 len
    ) {
        require(_len <= maxPerAmount && _len != 0);
        nfts = new WoofMineBrief[](_len);
        len = 0;

        uint256 bal = woofMine.totalSupply();
        if (bal == 0 || _index >= bal) {
            return (nfts, len);
        }

        for (uint8 i = 0; i < _len; ++i) {
            uint256 tokenId = woofMine.tokenByIndex(_index);
            nfts[i].woofMine = woofMinePool.woofMineBrief(uint32(tokenId));
            (nfts[i].woofMine.totalLootCount, nfts[i].woofMine.dailyLootCount) = loot.mineLootBrief(uint32(tokenId));
            nfts[i].owner = woofMine.ownerOf(tokenId);
            ++_index;
            ++len;
            if (_index >= bal) {
                return (nfts, len);
            }
        }
    }

    function getTokenDetails(uint32 _tokenId) public view returns(WoofMineBrief memory) {
        WoofMineBrief memory detail;
        detail.woofMine = woofMinePool.woofMineBrief(_tokenId);
        (detail.woofMine.totalLootCount, detail.woofMine.dailyLootCount) = loot.mineLootBrief(_tokenId);
        detail.owner = woofMine.ownerOf(_tokenId);
        return detail;
    }

    function farmInfo(address _user) public view returns(
        uint256 balance_,
        uint256 totalPawPendingRewards_,
        uint256 totalGemPendingRewards_
    ) {
        balance_ = balanceOf(_user);
        totalPawPendingRewards_ = 0;
        totalGemPendingRewards_ = 0;
        for (uint256 i = 0; i < balance_; ++i) {
            uint256 tokenId = woofMine.tokenOfOwnerByIndex(_user, i);
            IWoofMineEnumerable.WoofMineBrief memory ww = woofMinePool.woofMineBrief(uint32(tokenId));
            totalPawPendingRewards_ += ww.pendingPaw;
            totalGemPendingRewards_ += ww.pendingGem;
        }
    }
}