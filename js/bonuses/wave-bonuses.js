/**
 * wave-bonuses.js - Handles bonuses for completing waves
 * This module rewards players with currency and score bonuses
 * for completing waves.
 */

const WaveBonusModule = (function() {
    // Bonus multipliers based on wave number
    const baseBonus = 20; // Base bonus amount
    const currencyMultiplier = 1.0; // Base currency multiplier
    const scoreMultiplier = 2.0; // Base score multiplier
    
    /**
     * Calculate the wave completion bonus
     * @param {number} waveNumber - The completed wave number
     * @returns {Object} Bonus values for currency and score
     */
    function calculateWaveBonus(waveNumber) {
        // Scale bonus with wave number
        const scaleFactor = 1 + (waveNumber - 1) * 0.1; // 10% increase per wave
        
        const currencyBonus = Math.floor(baseBonus * waveNumber * currencyMultiplier * scaleFactor);
        const scoreBonus = Math.floor(baseBonus * waveNumber * scoreMultiplier * scaleFactor);
        
        return {
            currency: currencyBonus,
            score: scoreBonus
        };
    }
    
    /**
     * Apply the wave completion bonus
     * @param {number} waveNumber - The completed wave number
     */
    function applyWaveBonus(waveNumber) {
        if (!window.PlayerModule) {
            console.error("PlayerModule not found");
            return;
        }
        
        const bonus = calculateWaveBonus(waveNumber);
        
        // Add currency and score to player
        PlayerModule.addCurrency(bonus.currency);
        PlayerModule.addScore(bonus.score);
        
        // Show message about the bonus
        EventSystem.publish(GameEvents.STATUS_MESSAGE, 
            `Wave ${waveNumber} completed! Bonus: ${bonus.currency} currency, ${bonus.score} points`);
    }
    
    /**
     * Initialize event listeners
     */
    function initEventListeners() {
        // Listen for wave completion
        EventSystem.subscribe(GameEvents.WAVE_COMPLETE, function(data) {
            if (data && data.waveNumber) {
                applyWaveBonus(data.waveNumber);
            }
        });
    }
    
    // Initialize
    function init() {
        initEventListeners();
    }
    
    // Initialize event listeners
    init();
    
    // Public API
    return {
        calculateWaveBonus,
        applyWaveBonus
    };
})();

// Make module available globally
window.WaveBonusModule = WaveBonusModule;