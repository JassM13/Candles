// Utility functions for the chart application

// Logging utility
function logMessage(message) {
    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.log) {
        window.webkit.messageHandlers.log.postMessage(message);
    }
    console.log(message);
}

// Error handling utility
function logError(error, context = '') {
    const errorMessage = `❌ Error${context ? ` in ${context}` : ''}: ${error.message}`;
    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.error) {
        window.webkit.messageHandlers.error.postMessage(errorMessage);
    }
    console.error(errorMessage, error);
}

// Swift communication utilities
function notifyChartReady() {
    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.chartReady) {
        window.webkit.messageHandlers.chartReady.postMessage('ready');
    }
    logMessage('📊 Chart is ready, requesting data...');
}

function requestChartData() {
    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.dataRequest) {
        window.webkit.messageHandlers.dataRequest.postMessage('requestData');
    }
    logMessage('📊 Requesting chart data from Swift...');
}

// Data validation utilities
function validateChartData(data) {
    if (!data) {
        logError(new Error('Chart data is null or undefined'));
        return false;
    }
    
    if (!Array.isArray(data)) {
        logError(new Error('Chart data is not an array'));
        return false;
    }
    
    if (data.length === 0) {
        logMessage('📊 Chart data is empty');
        return true; // Empty data is valid, just means no candles to show
    }
    
    // Validate data structure
    const requiredFields = ['open', 'high', 'low', 'close', 'time'];
    const isValid = data.every(candle => {
        return requiredFields.every(field => candle.hasOwnProperty(field));
    });
    
    if (!isValid) {
        logError(new Error('Chart data contains invalid candle objects'));
        return false;
    }
    
    logMessage(`📊 Chart data validated: ${data.length} candles`);
    return true;
}

// Date formatting utilities
function formatDate(timestamp, format = 'short') {
    const date = new Date(timestamp);
    
    switch (format) {
        case 'short':
            return date.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
        case 'time':
            return date.toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit' });
        case 'full':
            return date.toLocaleString('en-US');
        default:
            return date.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
    }
}

// Price formatting utilities
function formatPrice(price, decimals = 2) {
    return parseFloat(price).toFixed(decimals);
}

// Canvas utilities
function getCanvasContext(canvas) {
    const ctx = canvas.getContext('2d');
    if (!ctx) {
        throw new Error('Failed to get 2D context from canvas');
    }
    return ctx;
}

// Device pixel ratio handling
function setupHighDPICanvas(canvas) {
    const rect = canvas.getBoundingClientRect();
    const dpr = window.devicePixelRatio || 1;
    
    canvas.width = rect.width * dpr;
    canvas.height = rect.height * dpr;
    
    const ctx = getCanvasContext(canvas);
    ctx.scale(dpr, dpr);
    
    return {
        width: rect.width,
        height: rect.height,
        dpr: dpr
    };
}

// Export utilities for use in other files
if (typeof module !== 'undefined' && module.exports) {
    module.exports = {
        logMessage,
        logError,
        notifyChartReady,
        requestChartData,
        validateChartData,
        formatDate,
        formatPrice,
        getCanvasContext,
        setupHighDPICanvas
    };
}