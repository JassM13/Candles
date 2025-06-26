// Chart controls functionality
class ChartControls {
    constructor() {
        this.currentTimeframe = '15m'; // Default timeframe
        this.initializeTimeframeControls();
    }
    
    initializeTimeframeControls() {
        const timeframeButtons = document.querySelectorAll('.timeframe-btn');
        
        timeframeButtons.forEach(button => {
            button.addEventListener('click', (event) => {
                this.handleTimeframeChange(event.target);
            });
        });
        
        // Set default active button
        this.setActiveTimeframe(this.currentTimeframe);
    }
    
    handleTimeframeChange(button) {
        // Remove active class from all buttons
        const timeframeButtons = document.querySelectorAll('.timeframe-btn');
        timeframeButtons.forEach(btn => btn.classList.remove('active'));
        
        // Add active class to clicked button
        button.classList.add('active');
        
        // Get selected timeframe
        const timeframe = button.dataset.timeframe;
        this.currentTimeframe = timeframe;
        
        // Notify Swift about timeframe change
        this.notifyTimeframeChange(timeframe);
        
        // Log the change
        this.logMessage(`📊 Timeframe changed to: ${timeframe}`);
    }
    
    setActiveTimeframe(timeframe) {
        const timeframeButtons = document.querySelectorAll('.timeframe-btn');
        timeframeButtons.forEach(btn => {
            btn.classList.remove('active');
            if (btn.dataset.timeframe === timeframe) {
                btn.classList.add('active');
            }
        });
        this.currentTimeframe = timeframe;
    }
    
    notifyTimeframeChange(timeframe) {
        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.timeframeChanged) {
            window.webkit.messageHandlers.timeframeChanged.postMessage(timeframe);
        }
    }
    
    logMessage(message) {
        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.log) {
            window.webkit.messageHandlers.log.postMessage(message);
        }
        console.log(message);
    }
    
    getCurrentTimeframe() {
        return this.currentTimeframe;
    }
}

// Export for use in other files
if (typeof module !== 'undefined' && module.exports) {
    module.exports = ChartControls;
}