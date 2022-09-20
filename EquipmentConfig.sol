// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.0;

import "./interfaces/IEquipment.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract EquipmentConfig is OwnableUpgradeable, IEquipmentConfig {

    mapping(uint16 => sEquipmentConfig) public equipmentConfigs;
    mapping(uint8 => sEquipmentLevelConfig[]) public equipmentLevelConfigs;
    mapping(uint8 => sEquipmentBoxConfig) public equipmentBoxConfigs;
    uint16[][3] public mintCid;

    function initialize() external initializer {
        __Ownable_init();
    }

    function setEquipmentConfig(sEquipmentConfig[] memory _configs) external onlyOwner {
        for (uint256 i = 0; i < _configs.length; ++i) {
            equipmentConfigs[_configs[i].cid] = _configs[i];
        }
    }

    function setEquipmentLevelConfig(sEquipmentLevelConfig[] memory _configs) external onlyOwner {
        delete equipmentLevelConfigs[0];
        delete equipmentLevelConfigs[1];
        delete equipmentLevelConfigs[2];
        for (uint256 i = 0; i < _configs.length; ++i) {
            equipmentLevelConfigs[_configs[i].eType].push(_configs[i]);
        }
    }

    function setEquipmentBoxConfig(sEquipmentBoxConfig[] memory _configs) external onlyOwner {
        for (uint256 i = 0; i < _configs.length; ++i) {
            equipmentBoxConfigs[_configs[i].eType] = _configs[i];
        }
    }

    function setMintCid(uint8 _eType, uint16[] memory _cid) external onlyOwner {
        require(_eType < 3);
        mintCid[_eType] = _cid;
    }

    
    function getConfig(uint16 _cid) external override view returns(sEquipmentConfig memory) {
        return equipmentConfigs[_cid];
    }

    function getLevelConfig(uint8 _type, uint8 _level) external override view returns(sEquipmentLevelConfig memory) {
        return equipmentLevelConfigs[_type][_level - 1];
    }

    function getEquipmentBoxConfig(uint8 _type) external override view returns(sEquipmentBoxConfig memory) {
        return equipmentBoxConfigs[_type];
    }

    function randomEquipment(uint256[] memory _seeds, uint8 _type) external override view returns(IEquipment.sEquipment memory) {
        uint256 pos = _seeds[0] % mintCid[_type].length;
        uint16 cid = mintCid[_type][pos];
        sEquipmentLevelConfig memory eLevelConfig = equipmentLevelConfigs[_type][0];
        IEquipment.sEquipment memory e;
        e.eType = _type;
        e.level = 1;
        e.cid = cid;
        e.hp = eLevelConfig.hp[0] + uint32(_seeds[1] % (eLevelConfig.hp[1] - eLevelConfig.hp[0]));
        e.attack = eLevelConfig.attack[0] + uint32(_seeds[2] % (eLevelConfig.attack[1] - eLevelConfig.attack[0]));
        e.hitRate = eLevelConfig.hitRate[0] + uint32(_seeds[3] % (eLevelConfig.hitRate[1] - eLevelConfig.hitRate[0]));
        return e;
    }
}