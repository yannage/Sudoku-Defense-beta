/**
 * types.js - Defines enemy types and their properties
 * This module contains the configuration for different enemy types
 * including their stats, rewards, and emoji representations.
 */

const EnemyTypes = (function() {
    // Enemy types with their properties
    const enemyTypes = {
        1: { 
            emoji: '1️⃣', 
            health: 60, 
            speed: 0.9, 
            reward: 15, 
            points: 5 
        },
        2: { 
            emoji: '2️⃣', 
            health: 70, 
            speed: 1.0, 
            reward: 18, 
            points: 7 
        },
        3: { 
            emoji: '3️⃣', 
            health: 80, 
            speed: 1.1, 
            reward: 21, 
            points: 9 
        },
        4: { 
            emoji: '4️⃣', 
            health: 90, 
            speed: 1.2, 
            reward: 24, 
            points: 11 
        },
        5: { 
            emoji: '5️⃣', 
            health: 100, 
            speed: 1.3, 
            reward: 27, 
            points: 13 
        },
        6: { 
            emoji: '6️⃣', 
            health: 120, 
            speed: 1.4, 
            reward: 30, 
            points: 15 
        },
        7: { 
            emoji: '7️⃣', 
            health: 140, 
            speed: 1.5, 
            reward: 33, 
            points: 17 
        },
        8: { 
            emoji: '8️⃣', 
            health: 160, 
            speed: 1.6, 
            reward: 36, 
            points: 19 
        },
        9: { 
            emoji: '9️⃣', 
            health: 180, 
            speed: 1.7, 
            reward: 39, 
            points: 21 
        },
        'boss': { 
            emoji: '👹', 
            health: 300, 
            speed: 0.7, 
            reward: 75, 
            points: 50 
        }
    };
    
    /**
     * Get an enemy type by ID
     * @param {string|number} enemyType - Enemy type ID
     * @returns {Object|null} Enemy type data or null if not found
     */
    function getEnemyType(enemyType) {
        return enemyTypes[enemyType] ? { ...enemyTypes[enemyType] } : null;
    }
    
    /**
     * Get all enemy types
     * @returns {Object} Copy of all enemy types
     */
    function getAllEnemyTypes() {
        return { ...enemyTypes };
    }
    
    /**
     * Get enemy types available for a specific wave
     * @param {number} waveNumber - Current wave number
     * @returns {Object} Available enemy types for this wave
     */
    function getAvailableTypesForWave(waveNumber) {
        // Determine which enemy types to use based on wave number
        const availableTypes = Math.min(9, Math.ceil(waveNumber / 2));
        const result = {};
        
        // Include regular number enemies up to availableTypes
        for (let i = 1; i <= availableTypes; i++) {
            result[i] = { ...enemyTypes[i] };
        }
        
        // Include boss enemy every third wave
        if (waveNumber % 3 === 0) {
            result['boss'] = { ...enemyTypes['boss'] };
        }
        
        return result;
    }
    
    /**
     * Apply wave scaling to enemy stats
     * @param {Object} enemyData - Base enemy data
     * @param {number} waveNumber - Current wave number
     * @returns {Object} Scaled enemy data
     */
    function applyWaveScaling(enemyData, waveNumber) {
        const healthScale = 1 + (waveNumber - 1) * 0.2; // 20% more health per wave
        const rewardScale = 1 + (waveNumber - 1) * 0.1; // 10% more reward per wave
        
        return {
            ...enemyData,
            health: Math.floor(enemyData.health * healthScale),
            maxHealth: Math.floor(enemyData.health * healthScale),
            reward: Math.floor(enemyData.reward * rewardScale),
            points: Math.floor(enemyData.points * (1 + (waveNumber - 1) * 0.05)) // 5% more points per wave
        };
    }
    
    // Public API
    return {
        getEnemyType,
        getAllEnemyTypes,
        getAvailableTypesForWave,
        applyWaveScaling
    };
})();

// Make module available globally
window.EnemyTypes = EnemyTypes;