// CandlestickChart class for rendering financial charts
class CandlestickChart {
    constructor(canvas) {
        this.canvas = canvas;
        this.ctx = canvas.getContext('2d');
        this.data = [];
        this.padding = { top: 0, right: 60, bottom: 30, left: 0 };
        this.isVisible = true;
        this.animationFrame = null;
        this.mouseX = 0;
        this.mouseY = 0;
        this.showCrosshair = false;
        this.touchHoldTimer = null;
        this.touchStartTime = 0;
        this.lastDrawTime = 0;
        this.drawThrottleMs = 16; // ~60fps throttling
        
        // Interactive viewport properties
        this.viewport = {
            startIndex: 0,
            endIndex: 0,
            priceMin: 0,
            priceMax: 0,
            candleWidth: 8,
            minCandleWidth: 2,
            maxCandleWidth: 20
        };
        
        // Pan and zoom state
        this.isDragging = false;
        this.lastMouseX = 0;
        this.lastMouseY = 0;
        this.zoomSensitivity = 0.1;
        
        // Grid configuration
        this.gridConfig = {
            maxHorizontalLines: 10,  // Maximum number of horizontal grid lines (configurable)
            minHorizontalLines: 7    // Minimum number of horizontal grid lines
        };
        
        // Professional dark theme colors with darker tones
        this.colors = {
            bullish: '#00C896',     // iOS-style green for bullish candles
            bearish: '#FF453A',     // iOS-style red for bearish candles
            background: '#000000',  // Pure black background
            grid: '#1C1C1E',        // Dark gray grid lines
            text: '#8E8E93',        // iOS secondary label color
            axis: '#2C2C2E',        // Darker axis lines
            gridMajor: '#2C2C2E',   // Major grid lines
            gridMinor: '#1C1C1E'    // Minor grid lines
        };
        
        this.initializeCanvas();
        this.setupVisibilityHandling();
        this.setupMouseHandling();
    }
    
    initializeCanvas() {
        const rect = this.canvas.getBoundingClientRect();
        const dpr = window.devicePixelRatio || 1;
        
        this.canvas.width = rect.width * dpr;
        this.canvas.height = rect.height * dpr;
        this.ctx.scale(dpr, dpr);
        
        this.width = rect.width;
        this.height = rect.height;
        
        this.chartWidth = this.width - this.padding.left - this.padding.right;
        this.chartHeight = this.height - this.padding.top - this.padding.bottom;
    }
    
    panChart(deltaX, deltaY) {
        if (!this.data || this.data.length === 0) return;
        
        // Pan horizontally (time) - maintain viewport range
        const candlesPerPixel = (this.viewport.endIndex - this.viewport.startIndex) / this.chartWidth;
        const candleShift = Math.round(deltaX * candlesPerPixel);
        const currentRange = this.viewport.endIndex - this.viewport.startIndex;
        
        let newStartIndex = this.viewport.startIndex - candleShift;
        let newEndIndex = this.viewport.endIndex - candleShift;
        
        // Prevent going beyond data boundaries while maintaining range
        if (newStartIndex < 0) {
            newStartIndex = 0;
            newEndIndex = Math.min(this.data.length - 1, currentRange);
        } else if (newEndIndex >= this.data.length) {
            newEndIndex = this.data.length - 1;
            newStartIndex = Math.max(0, newEndIndex - currentRange);
        }
        
        this.viewport.startIndex = newStartIndex;
        this.viewport.endIndex = newEndIndex;
        
        // Pan vertically (price)
        const priceRange = this.viewport.priceMax - this.viewport.priceMin;
        const pricePerPixel = priceRange / this.chartHeight;
        const priceShift = deltaY * pricePerPixel;
        
        this.viewport.priceMin += priceShift;
        this.viewport.priceMax += priceShift;
    }
    
    zoomChart(deltaY, mouseX, mouseY) {
        if (!this.data || this.data.length === 0) return;
        
        const zoomFactor = 1 + (deltaY > 0 ? this.zoomSensitivity : -this.zoomSensitivity);
        
        // Zoom horizontally (time)
        const mouseXRatio = (mouseX - this.padding.left) / this.chartWidth;
        const currentRange = this.viewport.endIndex - this.viewport.startIndex;
        const newRange = Math.max(10, Math.min(this.data.length, currentRange * zoomFactor));
        const rangeDiff = newRange - currentRange;
        
        let newStartIndex = this.viewport.startIndex - rangeDiff * mouseXRatio;
        let newEndIndex = newStartIndex + newRange;
        
        // Ensure we stay within data boundaries
        if (newStartIndex < 0) {
            newStartIndex = 0;
            newEndIndex = Math.min(this.data.length - 1, newRange);
        } else if (newEndIndex >= this.data.length) {
            newEndIndex = this.data.length - 1;
            newStartIndex = Math.max(0, newEndIndex - newRange);
        }
        
        this.viewport.startIndex = newStartIndex;
        this.viewport.endIndex = newEndIndex;
        
        // Update candle width based on actual range
        const actualRange = this.viewport.endIndex - this.viewport.startIndex;
        this.viewport.candleWidth = Math.max(this.viewport.minCandleWidth, 
            Math.min(this.viewport.maxCandleWidth, this.chartWidth / actualRange * 0.8));
        
        // Zoom vertically (price)
        const mouseYRatio = (mouseY - this.padding.top) / this.chartHeight;
        const currentPriceRange = this.viewport.priceMax - this.viewport.priceMin;
        const newPriceRange = currentPriceRange * zoomFactor;
        const priceDiff = newPriceRange - currentPriceRange;
        
        this.viewport.priceMin -= priceDiff * (1 - mouseYRatio);
        this.viewport.priceMax += priceDiff * mouseYRatio;
    }
    
    setData(data) {
        // Prevent unnecessary redraws if data hasn't changed
        if (this.data && data && this.data.length === data.length) {
            // Quick check if data is the same (compare first and last elements)
            const isSameData = this.data.length > 0 && 
                this.data[0].time === data[0].time &&
                this.data[this.data.length - 1].time === data[data.length - 1].time &&
                this.data[this.data.length - 1].close === data[data.length - 1].close;
            
            if (isSameData) {
                return; // Skip redraw if data is identical
            }
        }
        
        this.data = data;
        if (data && data.length > 0) {
            this.calculateBounds();
            this.initializeViewport();
            this.requestDraw();
        }
    }
    
    initializeViewport() {
        if (!this.data || this.data.length === 0) return;
        
        // Initialize viewport with proper bounds and margin to prevent candles extending too far right
        const visibleCandles = Math.floor(this.chartWidth / this.viewport.candleWidth);
        const marginCandles = Math.floor(visibleCandles * 0.1); // 10% margin
        this.viewport.endIndex = this.data.length - 1 - marginCandles;
        this.viewport.startIndex = Math.max(0, this.viewport.endIndex - visibleCandles + marginCandles);
        this.viewport.priceMin = this.minPrice;
        this.viewport.priceMax = this.maxPrice;
    }
    
    setupVisibilityHandling() {
        // Handle page visibility changes to prevent jittery animations
        document.addEventListener('visibilitychange', () => {
            this.isVisible = !document.hidden;
            if (this.isVisible && this.data.length > 0) {
                this.requestDraw();
            }
        });
        
        // Handle window focus/blur
        window.addEventListener('focus', () => {
            this.isVisible = true;
            if (this.data.length > 0) {
                this.requestDraw();
            }
        });
        
        window.addEventListener('blur', () => {
            this.isVisible = false;
            if (this.animationFrame) {
                cancelAnimationFrame(this.animationFrame);
                this.animationFrame = null;
            }
        });
    }
    
    requestDraw() {
        if (!this.isVisible) return;
        
        const now = performance.now();
        const timeSinceLastDraw = now - this.lastDrawTime;
        
        if (this.animationFrame) {
            cancelAnimationFrame(this.animationFrame);
        }
        
        // Throttle drawing to prevent excessive redraws
        if (timeSinceLastDraw < this.drawThrottleMs) {
            this.animationFrame = requestAnimationFrame(() => {
                this.requestDraw();
            });
            return;
        }
        
        this.animationFrame = requestAnimationFrame(() => {
            this.draw();
            this.lastDrawTime = performance.now();
            this.animationFrame = null;
        });
    }
    
    // Method to configure grid settings (user-configurable)
    setGridConfig(config) {
        if (config.maxHorizontalLines !== undefined) {
            this.gridConfig.maxHorizontalLines = Math.max(3, Math.min(20, config.maxHorizontalLines));
        }
        if (config.minHorizontalLines !== undefined) {
            this.gridConfig.minHorizontalLines = Math.max(1, Math.min(this.gridConfig.maxHorizontalLines, config.minHorizontalLines));
        }
        // Redraw chart with new grid configuration
        if (this.data.length > 0) {
            this.requestDraw();
        }
    }
    
    // Method to get current grid configuration
    getGridConfig() {
        return { ...this.gridConfig };
    }

    setupMouseHandling() {
        // Prevent iOS magnifier and text selection
        this.canvas.style.webkitUserSelect = 'none';
        this.canvas.style.userSelect = 'none';
        this.canvas.style.webkitTouchCallout = 'none';
        this.canvas.style.webkitTapHighlightColor = 'transparent';
        
        // Mouse events
        this.canvas.addEventListener('mousedown', (e) => {
            e.preventDefault();
            this.isDragging = true;
            const rect = this.canvas.getBoundingClientRect();
            this.lastMouseX = e.clientX - rect.left;
            this.lastMouseY = e.clientY - rect.top;
            this.canvas.style.cursor = 'grabbing';
        });
        
        this.canvas.addEventListener('mousemove', (e) => {
            e.preventDefault();
            const rect = this.canvas.getBoundingClientRect();
            this.mouseX = e.clientX - rect.left;
            this.mouseY = e.clientY - rect.top;
            
            if (this.isDragging) {
                const deltaX = this.mouseX - this.lastMouseX;
                const deltaY = this.mouseY - this.lastMouseY;
                
                this.panChart(deltaX, deltaY);
                
                this.lastMouseX = this.mouseX;
                this.lastMouseY = this.mouseY;
            } else {
                this.showCrosshair = true;
            }
            
            this.requestDraw();
        });
        
        this.canvas.addEventListener('mouseup', (e) => {
            e.preventDefault();
            this.isDragging = false;
            this.canvas.style.cursor = 'crosshair';
        });
        
        this.canvas.addEventListener('mouseleave', () => {
            this.isDragging = false;
            this.showCrosshair = false;
            this.canvas.style.cursor = 'default';
            this.requestDraw();
        });
        
        this.canvas.addEventListener('mouseenter', () => {
            this.showCrosshair = true;
            this.canvas.style.cursor = 'crosshair';
        });
        
        this.canvas.addEventListener('wheel', (e) => {
            e.preventDefault();
            const rect = this.canvas.getBoundingClientRect();
            const mouseX = e.clientX - rect.left;
            const mouseY = e.clientY - rect.top;
            
            this.zoomChart(e.deltaY, mouseX, mouseY);
            this.requestDraw();
        });
        
        // Touch events for mobile (prevent iOS magnifier)
        this.canvas.addEventListener('touchstart', (e) => {
            e.preventDefault();
            if (e.touches.length === 1) {
                const rect = this.canvas.getBoundingClientRect();
                this.mouseX = e.touches[0].clientX - rect.left;
                this.mouseY = e.touches[0].clientY - rect.top;
                this.lastMouseX = this.mouseX;
                this.lastMouseY = this.mouseY;
                this.touchStartTime = Date.now();
                this.isDragging = false; // Start as not dragging
                
                // Set a timer to show crosshair after a brief hold
                this.touchHoldTimer = setTimeout(() => {
                    if (!this.isDragging) {
                        this.showCrosshair = true;
                        this.requestDraw();
                    }
                }, 200); // Show crosshair after 200ms of holding
            }
        }, { passive: false });
        
        this.canvas.addEventListener('touchmove', (e) => {
            e.preventDefault();
            if (e.touches.length === 1) {
                const rect = this.canvas.getBoundingClientRect();
                const newMouseX = e.touches[0].clientX - rect.left;
                const newMouseY = e.touches[0].clientY - rect.top;
                
                const deltaX = newMouseX - this.lastMouseX;
                const deltaY = newMouseY - this.lastMouseY;
                
                // If there's significant movement, start dragging
                if (Math.abs(deltaX) > 5 || Math.abs(deltaY) > 5) {
                    if (this.touchHoldTimer) {
                        clearTimeout(this.touchHoldTimer);
                        this.touchHoldTimer = null;
                    }
                    this.isDragging = true;
                    this.showCrosshair = false;
                    this.panChart(deltaX, deltaY);
                    this.lastMouseX = newMouseX;
                    this.lastMouseY = newMouseY;
                } else if (this.showCrosshair) {
                    // Update crosshair position for small movements
                    this.mouseX = newMouseX;
                    this.mouseY = newMouseY;
                }
                
                this.requestDraw();
            }
        }, { passive: false });
        
        // Handle touch events outside canvas to maintain crosshair
        document.addEventListener('touchmove', (e) => {
            if (this.showCrosshair && e.touches.length === 1) {
                const rect = this.canvas.getBoundingClientRect();
                const newMouseX = e.touches[0].clientX - rect.left;
                const newMouseY = e.touches[0].clientY - rect.top;
                
                // Update crosshair position even when outside canvas
                this.mouseX = newMouseX;
                this.mouseY = newMouseY;
                this.requestDraw();
            }
        }, { passive: false });
        
        document.addEventListener('touchend', (e) => {
            if (this.showCrosshair) {
                this.showCrosshair = false;
                this.requestDraw();
            }
        }, { passive: false });
        
        this.canvas.addEventListener('touchend', (e) => {
            e.preventDefault();
            if (this.touchHoldTimer) {
                clearTimeout(this.touchHoldTimer);
                this.touchHoldTimer = null;
            }
            this.isDragging = false;
            this.showCrosshair = false;
            this.requestDraw();
        }, { passive: false });
    }
    
    calculateBounds() {
        if (!this.data || this.data.length === 0) return;
        
        this.minPrice = Math.min(...this.data.map(d => d.low));
        this.maxPrice = Math.max(...this.data.map(d => d.high));
        this.priceRange = this.maxPrice - this.minPrice;
        
        // Add some padding to the price range
        const padding = this.priceRange * 0.1;
        this.minPrice -= padding;
        this.maxPrice += padding;
        this.priceRange = this.maxPrice - this.minPrice;
        
        this.chartWidth = this.width - this.padding.left - this.padding.right;
        this.chartHeight = this.height - this.padding.top - this.padding.bottom;
    }
    
    draw() {
        this.clear();
        if (!this.data || this.data.length === 0) {
            this.drawNoDataMessage();
            return;
        }
        
        this.drawGrid();
        this.drawCandles();
        this.drawSeparators();
        this.drawPriceAxis();
        this.drawTimeAxis();
        
        if (this.showCrosshair) {
            this.drawCrosshair();
        }
    }
    
    clear() {
        this.ctx.fillStyle = this.colors.background;
        this.ctx.fillRect(0, 0, this.width, this.height);
    }
    
    drawNoDataMessage() {
        this.ctx.fillStyle = this.colors.text;
        this.ctx.font = '16px Arial';
        this.ctx.textAlign = 'center';
        this.ctx.fillText('No candle data available', this.width / 2, this.height / 2);
    }
    
    drawGrid() {
        this.ctx.strokeStyle = this.colors.grid;
        this.ctx.lineWidth = 0.5;
        this.ctx.beginPath();
        
        // Sticky horizontal grid lines that move with price data
        this.drawStickyHorizontalGrid();
        
        // Sticky vertical grid lines that move with data
        this.drawStickyVerticalGrid();
        
        this.ctx.stroke();
    }
    
    drawStickyHorizontalGrid() {
        if (!this.data || this.data.length === 0) return;
        
        const priceRange = this.viewport.priceMax - this.viewport.priceMin;
        const maxLines = this.gridConfig.maxHorizontalLines;
        const minLines = this.gridConfig.minHorizontalLines;
        
        // Calculate optimal price step based on desired number of grid lines
        const targetLines = Math.min(maxLines, Math.max(minLines, Math.floor(this.chartHeight / 60))); // ~60px between lines
        const rawStep = priceRange / targetLines;
        
        // Round to nice numbers (1, 2, 5, 10, 20, 50, 100, etc.)
        const magnitude = Math.pow(10, Math.floor(Math.log10(rawStep)));
        const normalizedStep = rawStep / magnitude;
        
        let niceStep;
        if (normalizedStep <= 1) {
            niceStep = 1;
        } else if (normalizedStep <= 2) {
            niceStep = 2;
        } else if (normalizedStep <= 5) {
            niceStep = 5;
        } else {
            niceStep = 10;
        }
        
        const priceStep = niceStep * magnitude;
        
        // Find the first and last price levels
        const minPrice = Math.floor(this.viewport.priceMin / priceStep) * priceStep;
        const maxPrice = Math.ceil(this.viewport.priceMax / priceStep) * priceStep;
        
        // Count and limit the actual number of lines
        const gridPrices = [];
        for (let price = minPrice; price <= maxPrice; price += priceStep) {
            if (price >= this.viewport.priceMin && price <= this.viewport.priceMax) {
                gridPrices.push(price);
            }
        }
        
        // If we still have too many lines, thin them out
        if (gridPrices.length > maxLines) {
            const step = Math.ceil(gridPrices.length / maxLines);
            const thinned = [];
            for (let i = 0; i < gridPrices.length; i += step) {
                thinned.push(gridPrices[i]);
            }
            gridPrices.length = 0;
            gridPrices.push(...thinned.slice(0, maxLines));
        }
        
        // Draw the grid lines
        for (const price of gridPrices) {
            const y = this.padding.top + (1 - (price - this.viewport.priceMin) / priceRange) * this.chartHeight;
            
            // Only draw if within chart area
            if (y >= this.padding.top && y <= this.height - this.padding.bottom) {
                this.ctx.moveTo(this.padding.left, Math.round(y) + 0.5);
                this.ctx.lineTo(this.width - this.padding.right, Math.round(y) + 0.5);
            }
        }
    }
    
    drawStickyVerticalGrid() {
        if (!this.data || this.data.length === 0) return;
        
        const visibleRange = this.viewport.endIndex - this.viewport.startIndex;
        const candleWidth = this.chartWidth / visibleRange;
        
        // Calculate optimal grid spacing for smooth movement
        let timeSpacing;
        if (candleWidth > 50) {
            timeSpacing = 1; // Every candle when very zoomed in
        } else if (candleWidth > 25) {
            timeSpacing = 2; // Every 2 candles
        } else if (candleWidth > 15) {
            timeSpacing = 5; // Every 5 candles
        } else if (candleWidth > 8) {
            timeSpacing = 10; // Every 10 candles
        } else if (candleWidth > 4) {
            timeSpacing = 20; // Every 20 candles
        } else if (candleWidth > 2) {
            timeSpacing = 50; // Every 50 candles
        } else {
            timeSpacing = 100; // Every 100 candles when zoomed out
        }
        
        // Calculate smooth grid positions
        const startIndex = Math.floor(this.viewport.startIndex);
        const endIndex = Math.ceil(this.viewport.endIndex);
        
        // Find the first grid line position
        const firstGridIndex = Math.floor(startIndex / timeSpacing) * timeSpacing;
        
        // Draw vertical grid lines with smooth positioning
        for (let dataIndex = firstGridIndex; dataIndex <= endIndex + timeSpacing; dataIndex += timeSpacing) {
            if (dataIndex < 0 || dataIndex >= this.data.length) continue;
            
            // Calculate exact position with sub-pixel precision
            const exactPosition = dataIndex - this.viewport.startIndex;
            const x = this.padding.left + (exactPosition / visibleRange) * this.chartWidth;
            
            // Only draw if within visible area with some margin
            if (x >= this.padding.left - 10 && x <= this.width - this.padding.right + 10) {
                this.ctx.moveTo(Math.round(x) + 0.5, this.padding.top);
                this.ctx.lineTo(Math.round(x) + 0.5, this.height - this.padding.bottom);
            }
        }
    }
    
    drawPriceAxis() {
        this.ctx.font = '12px -apple-system, BlinkMacSystemFont, sans-serif';
        this.ctx.textAlign = 'center';
        
        const priceRange = this.viewport.priceMax - this.viewport.priceMin;
        const maxLines = this.gridConfig.maxHorizontalLines;
        const minLines = this.gridConfig.minHorizontalLines;
        
        // Use the same calculation as grid to ensure perfect alignment
        const targetLines = Math.min(maxLines, Math.max(minLines, Math.floor(this.chartHeight / 60)));
        const rawStep = priceRange / targetLines;
        
        // Round to nice numbers (same logic as grid)
        const magnitude = Math.pow(10, Math.floor(Math.log10(rawStep)));
        const normalizedStep = rawStep / magnitude;
        
        let niceStep;
        if (normalizedStep <= 1) {
            niceStep = 1;
        } else if (normalizedStep <= 2) {
            niceStep = 2;
        } else if (normalizedStep <= 5) {
            niceStep = 5;
        } else {
            niceStep = 10;
        }
        
        const priceStep = niceStep * magnitude;
        
        // Find the first and last price levels
        const minPrice = Math.floor(this.viewport.priceMin / priceStep) * priceStep;
        const maxPrice = Math.ceil(this.viewport.priceMax / priceStep) * priceStep;
        
        // Calculate the same grid prices as the grid method
        const gridPrices = [];
        for (let price = minPrice; price <= maxPrice; price += priceStep) {
            if (price >= this.viewport.priceMin && price <= this.viewport.priceMax) {
                gridPrices.push(price);
            }
        }
        
        // Apply the same thinning logic
        if (gridPrices.length > maxLines) {
            const step = Math.ceil(gridPrices.length / maxLines);
            const thinned = [];
            for (let i = 0; i < gridPrices.length; i += step) {
                thinned.push(gridPrices[i]);
            }
            gridPrices.length = 0;
            gridPrices.push(...thinned.slice(0, maxLines));
        }
        
        // Draw price labels for each grid line
        for (const price of gridPrices) {
            const y = this.padding.top + (1 - (price - this.viewport.priceMin) / priceRange) * this.chartHeight;
            
            // Only draw if within chart area
            if (y >= this.padding.top && y <= this.height - this.padding.bottom) {
                const text = this.formatPrice(price);
                
                // Draw price text centered in the price axis area
                this.ctx.fillStyle = this.colors.text;
                const priceAxisCenter = this.width - this.padding.right / 2;
                this.ctx.fillText(text, priceAxisCenter, Math.round(y) + 4);
            }
        }
    }
    
    drawTimeAxis() {
        this.ctx.font = '12px -apple-system, BlinkMacSystemFont, sans-serif';
        this.ctx.textAlign = 'center';
        
        const visibleRange = this.viewport.endIndex - this.viewport.startIndex;
        const candleWidth = this.chartWidth / visibleRange;
        
        // Calculate time label spacing that matches grid
        let timeSpacing;
        if (candleWidth > 50) {
            timeSpacing = 1;
        } else if (candleWidth > 25) {
            timeSpacing = 2;
        } else if (candleWidth > 15) {
            timeSpacing = 5;
        } else if (candleWidth > 8) {
            timeSpacing = 10;
        } else if (candleWidth > 4) {
            timeSpacing = 20;
        } else if (candleWidth > 2) {
            timeSpacing = 50;
        } else {
            timeSpacing = 100;
        }
        
        const startIndex = Math.floor(this.viewport.startIndex);
        const endIndex = Math.ceil(this.viewport.endIndex);
        const firstLabelIndex = Math.floor(startIndex / timeSpacing) * timeSpacing;
        
        // Draw time labels synchronized with grid
        for (let dataIndex = firstLabelIndex; dataIndex <= endIndex + timeSpacing; dataIndex += timeSpacing) {
            if (dataIndex < 0 || dataIndex >= this.data.length) continue;
            
            const exactPosition = dataIndex - this.viewport.startIndex;
            const x = this.padding.left + (exactPosition / visibleRange) * this.chartWidth;
            
            // Only draw if within visible area
            if (x >= this.padding.left + 30 && x <= this.width - this.padding.right - 30) {
                const date = new Date(this.data[dataIndex].time);
                let label;
                
                // Format based on time spacing
                if (timeSpacing <= 5) {
                    label = date.toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit' });
                } else {
                    label = date.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
                }
                
                this.ctx.fillStyle = this.colors.text;
                // Center labels in the time axis area
                const timeAxisCenter = this.height - this.padding.bottom / 2;
                this.ctx.fillText(label, Math.round(x), timeAxisCenter);
            }
        }
    }
    
    drawCandles() {
        if (!this.data || this.data.length === 0) return;
        
        const candleWidth = this.viewport.candleWidth;
        const wickWidth = Math.max(1, candleWidth * 0.1);
        const visibleRange = this.viewport.endIndex - this.viewport.startIndex;
        const priceRange = this.viewport.priceMax - this.viewport.priceMin;
        
        // Chart boundaries to prevent overlap with axes
        const chartTop = this.padding.top;
        const chartBottom = this.height - this.padding.bottom;
        const chartLeft = this.padding.left;
        const chartRight = this.width - this.padding.right;
        
        // Only draw visible candles
        for (let i = Math.floor(this.viewport.startIndex); i <= Math.ceil(this.viewport.endIndex) && i < this.data.length; i++) {
            if (i < 0) continue;
            
            const candle = this.data[i];
            const relativeIndex = i - this.viewport.startIndex;
            const x = this.padding.left + (relativeIndex / visibleRange) * this.chartWidth;
            
            // Skip candles outside chart boundaries with stricter bounds to prevent showing through separator
            if (x < chartLeft + candleWidth/2 || x > chartRight - candleWidth/2) continue;
            
            let openY = this.padding.top + (1 - (candle.open - this.viewport.priceMin) / priceRange) * this.chartHeight;
            let closeY = this.padding.top + (1 - (candle.close - this.viewport.priceMin) / priceRange) * this.chartHeight;
            let highY = this.padding.top + (1 - (candle.high - this.viewport.priceMin) / priceRange) * this.chartHeight;
            let lowY = this.padding.top + (1 - (candle.low - this.viewport.priceMin) / priceRange) * this.chartHeight;
            
            // Clamp candle elements to chart boundaries
            openY = Math.max(chartTop, Math.min(chartBottom, openY));
            closeY = Math.max(chartTop, Math.min(chartBottom, closeY));
            highY = Math.max(chartTop, Math.min(chartBottom, highY));
            lowY = Math.max(chartTop, Math.min(chartBottom, lowY));
            
            const isBullish = candle.close > candle.open;
            const color = isBullish ? this.colors.bullish : this.colors.bearish;
            
            // Draw wick only within chart boundaries
            if (highY < chartBottom && lowY > chartTop) {
                this.ctx.strokeStyle = color;
                this.ctx.lineWidth = wickWidth;
                this.ctx.beginPath();
                this.ctx.moveTo(x, Math.max(chartTop, highY));
                this.ctx.lineTo(x, Math.min(chartBottom, lowY));
                this.ctx.stroke();
            }
            
            // Draw body only within chart boundaries
            const bodyTop = Math.min(openY, closeY);
            const bodyHeight = Math.abs(closeY - openY);
            if (bodyTop < chartBottom && (bodyTop + bodyHeight) > chartTop) {
                this.ctx.fillStyle = color;
                const clampedBodyTop = Math.max(chartTop, bodyTop);
                const clampedBodyHeight = Math.min(chartBottom - clampedBodyTop, bodyHeight - (clampedBodyTop - bodyTop));
                this.ctx.fillRect(x - candleWidth / 2, clampedBodyTop, candleWidth, Math.max(1, clampedBodyHeight));
            }
        }
    }
    
    formatPrice(price) {
        // Format price with appropriate decimal places based on value
        if (price >= 1000) {
            return price.toFixed(0);
        } else if (price >= 100) {
            return price.toFixed(1);
        } else if (price >= 1) {
            return price.toFixed(2);
        } else {
            return price.toFixed(4);
        }
    }
    

     drawCrosshair() {
         if (!this.showCrosshair) return;
         
         this.ctx.strokeStyle = this.colors.text;
         this.ctx.lineWidth = 1;
         this.ctx.setLineDash([4, 4]);
         this.ctx.beginPath();
         
         // Vertical crosshair line (show within chart area)
         if (this.mouseX >= this.padding.left && this.mouseX <= this.width - this.padding.right) {
             this.ctx.moveTo(this.mouseX, this.padding.top);
             this.ctx.lineTo(this.mouseX, this.height - this.padding.bottom);
         }
         
         // Horizontal crosshair line (show within chart area)
         if (this.mouseY >= this.padding.top && this.mouseY <= this.height - this.padding.bottom) {
             this.ctx.moveTo(this.padding.left, this.mouseY);
             this.ctx.lineTo(this.width - this.padding.right, this.mouseY);
         }
         
         this.ctx.stroke();
         this.ctx.setLineDash([]); // Reset line dash
         
         // Draw price and time labels at crosshair position
         this.drawCrosshairLabels();
     }
     
     drawCrosshairLabels() {
         if (!this.showCrosshair || !this.data || this.data.length === 0) return;
         
         // Only show labels when mouse is within chart area
         const isInChartArea = this.mouseX >= this.padding.left && 
                              this.mouseX <= this.width - this.padding.right &&
                              this.mouseY >= this.padding.top && 
                              this.mouseY <= this.height - this.padding.bottom;
         
         if (!isInChartArea) return;
         
         // Calculate price at mouse position using viewport
         const viewportPriceRange = this.viewport.priceMax - this.viewport.priceMin;
         const priceAtMouse = this.viewport.priceMax - ((this.mouseY - this.padding.top) / this.chartHeight) * viewportPriceRange;
         
         // Calculate time index at mouse position using viewport
         const visibleRange = this.viewport.endIndex - this.viewport.startIndex;
         const relativeMouseX = (this.mouseX - this.padding.left) / this.chartWidth;
         const timeIndex = Math.round(this.viewport.startIndex + relativeMouseX * visibleRange);
         
         // Ensure timeIndex is within valid bounds
         const validTimeIndex = Math.max(0, Math.min(this.data.length - 1, timeIndex));
         
         // Draw price label
         const priceText = this.formatPrice(priceAtMouse);
         this.ctx.font = '12px -apple-system, BlinkMacSystemFont, sans-serif';
         const priceTextWidth = this.ctx.measureText(priceText).width;
         const priceLabelPadding = 6;
         const priceLabelHeight = 18;
         
         this.ctx.fillStyle = '#007AFF';
         this.ctx.fillRect(
             this.width - priceTextWidth - priceLabelPadding * 2 - 5,
             this.mouseY - priceLabelHeight / 2,
             priceTextWidth + priceLabelPadding * 2,
             priceLabelHeight
         );
         
         this.ctx.fillStyle = '#FFFFFF';
         this.ctx.textAlign = 'right';
         this.ctx.fillText(priceText, this.width - priceLabelPadding - 5, this.mouseY + 4);
         
         // Draw time label
         const date = new Date(this.data[validTimeIndex].time);
         const timeText = date.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
         const timeTextWidth = this.ctx.measureText(timeText).width;
         const timeLabelPadding = 6;
         const timeLabelHeight = 18;
         
         this.ctx.fillStyle = '#007AFF';
         this.ctx.fillRect(
             this.mouseX - timeTextWidth / 2 - timeLabelPadding,
             this.height - timeLabelHeight - 5,
             timeTextWidth + timeLabelPadding * 2,
             timeLabelHeight
         );
         
         this.ctx.fillStyle = '#FFFFFF';
         this.ctx.textAlign = 'center';
         this.ctx.fillText(timeText, this.mouseX, this.height - 8);
     }
     
     drawSeparators() {
        this.ctx.strokeStyle = this.colors.axis;
        this.ctx.lineWidth = 1;
        this.ctx.beginPath();
        
        // Horizontal separator above time axis (edge to edge)
        const timeAxisSeparatorY = this.height - this.padding.bottom;
        this.ctx.moveTo(0, timeAxisSeparatorY);
        this.ctx.lineTo(this.width, timeAxisSeparatorY);
        
        // Vertical separator to the left of price axis (edge to edge)
        const priceAxisSeparatorX = this.width - this.padding.right;
        this.ctx.moveTo(priceAxisSeparatorX, 0);
        this.ctx.lineTo(priceAxisSeparatorX, this.height);
        
        this.ctx.stroke();
    }
 }

// Export for use in other files
if (typeof module !== 'undefined' && module.exports) {
    module.exports = CandlestickChart;
}