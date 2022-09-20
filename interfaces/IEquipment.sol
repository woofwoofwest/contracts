// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.0;

import "./IERC721Enumerable.sol";

interface IEquipment {
    struct sEquipment {
        uint8 level;
        uint8 eType;
        uint16 cid;  
        uint32 hp;    
        uint32 attack; 
        uint32 hitRate;
        uint32 tokenId;
    }

    function mint(address _to, uint8 _type) external returns(sEquipment memory);
    function updateTokenTraits(sEquipment memory _e) external;
    function getTokenTraits(uint256 _tokenId) external view returns (sEquipment memory);
    function getConfig(uint16 _cid) external view returns(IEquipmentConfig.sEquipmentConfig memory);
    function getLevelConfig(uint8 _type, uint8 _level) external view returns(IEquipmentConfig.sEquipmentLevelConfig memory);
    function getEquipmentBoxConfig(uint8 _type) external view returns(IEquipmentConfig.sEquipmentBoxConfig memory);
}
interface IEquipmentEnumerable is IEquipment, IERC721Enumerable {}


interface IEquipmentConfig {
    struct sEquipmentConfig {
        uint8 eType;
        uint16 cid;
        string name;
        string des;
    }

    struct sEquipmentLevelConfig {
        uint8 eType;
        uint8 costToken;
        uint16[2] hp;
        uint16[2] attack;
        uint16[2] hitRate; 
        uint256 cost; 
    }

    struct sEquipmentBoxConfig {
        uint8 eType;
        uint8 cid;
        uint8 payToken; //0: Paw, 1: Gem
        uint32 dailyLimit;
        uint256 price;
        string name;
        string des;
    }

    function getConfig(uint16 _cid) external view returns(sEquipmentConfig memory);
    function getLevelConfig(uint8 _type, uint8 _level) external view returns(sEquipmentLevelConfig memory);
    function getEquipmentBoxConfig(uint8 _type) external view returns(sEquipmentBoxConfig memory);
    function randomEquipment(uint256[] memory _seeds, uint8 _type) external view returns(IEquipment.sEquipment memory);
}