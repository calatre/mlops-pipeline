// MLOps Dashboard JavaScript

// Global state
let kinesisPollingInterval = null;
let autoEventInterval = null;
let isAutoEventsRunning = false;

// Initialize dashboard
document.addEventListener('DOMContentLoaded', function() {
    initializeEventListeners();
    checkSystemHealth();
    startKinesisPolling();
    loadS3Files();
});

// Event Listeners
function initializeEventListeners() {
    // Event type toggle
    document.querySelectorAll('input[name="eventType"]').forEach(radio => {
        radio.addEventListener('change', function() {
            document.getElementById('synthetic-options').style.display = 
                this.value === 'synthetic' ? 'block' : 'none';
            document.getElementById('s3-options').style.display = 
                this.value === 's3' ? 'block' : 'none';
        });
    });

    // Send event button
    document.getElementById('send-event-btn').addEventListener('click', sendTestEvent);

    // Refresh output button
    document.getElementById('refresh-output').addEventListener('click', refreshKinesisOutput);
}

// Check system health
async function checkSystemHealth() {
    // Check Airflow
    checkServiceHealth('airflow', '/airflow/health');
    
    // Check MLflow
    checkServiceHealth('mlflow', '/mlflow/health');
    
    // Check Kinesis
    checkAWSServiceHealth('kinesis');
    
    // Check Lambda
    checkAWSServiceHealth('lambda');
}

// Check individual service health
async function checkServiceHealth(service, endpoint) {
    const statusElement = document.getElementById(`${service}-status`);
    
    try {
        const response = await fetch(endpoint, { method: 'HEAD' });
        updateHealthStatus(statusElement, response.ok);
    } catch (error) {
        updateHealthStatus(statusElement, false);
    }
}

// Check AWS service health
async function checkAWSServiceHealth(service) {
    const statusElement = document.getElementById(`${service}-status`);
    
    try {
        const response = await fetch(`/api/health/${service}`);
        const data = await response.json();
        updateHealthStatus(statusElement, data.healthy);
    } catch (error) {
        updateHealthStatus(statusElement, false);
    }
}

// Update health status display
function updateHealthStatus(element, isHealthy) {
    element.innerHTML = isHealthy 
        ? '<i class="bi bi-check-circle-fill status-healthy"></i> <span class="status-text status-healthy">Healthy</span>'
        : '<i class="bi bi-x-circle-fill status-unhealthy"></i> <span class="status-text status-unhealthy">Unhealthy</span>';
}

// Send test event
async function sendTestEvent() {
    const eventType = document.querySelector('input[name="eventType"]:checked').value;
    const button = document.getElementById('send-event-btn');
    
    // Disable button and show loading
    button.disabled = true;
    button.innerHTML = '<span class="spinner-border spinner-border-sm"></span> Sending...';
    
    try {
        let payload = {};
        
        if (eventType === 'synthetic') {
            payload = {
                type: 'synthetic',
                data: {
                    trip_duration: parseInt(document.getElementById('tripDuration').value),
                    passenger_count: parseInt(document.getElementById('passengerCount').value),
                    timestamp: new Date().toISOString()
                }
            };
        } else {
            payload = {
                type: 's3',
                data: {
                    s3_key: document.getElementById('s3Key').value
                }
            };
        }
        
        const response = await fetch('/api/events', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payload)
        });
        
        const result = await response.json();
        
        if (response.ok) {
            addLogEntry(`Event sent successfully: ${result.event_id}`, 'success');
            refreshKinesisOutput();
        } else {
            addLogEntry(`Failed to send event: ${result.message}`, 'error');
        }
    } catch (error) {
        addLogEntry(`Error sending event: ${error.message}`, 'error');
    } finally {
        // Re-enable button
        button.disabled = false;
        button.innerHTML = '<i class="bi bi-send-fill"></i> Send Event';
    }
}

// Refresh Kinesis output
async function refreshKinesisOutput() {
    try {
        const response = await fetch('/api/kinesis/records');
        const data = await response.json();
        
        const outputDiv = document.getElementById('kinesis-output');
        
        if (data.records && data.records.length > 0) {
            outputDiv.innerHTML = data.records.map(record => {
                const timestamp = new Date(record.timestamp).toLocaleTimeString();
                return `
                    <div class="output-entry">
                        <span class="timestamp">[${timestamp}]</span>
                        <span class="prediction">Prediction: ${record.prediction?.toFixed(2)} minutes</span>
                        ${record.model_version ? `<span> (Model v${record.model_version})</span>` : ''}
                    </div>
                `;
            }).join('');
        } else {
            outputDiv.innerHTML = '<p class="text-muted">No recent records found in stream.</p>';
        }
    } catch (error) {
        document.getElementById('kinesis-output').innerHTML = 
            '<p class="error">Error fetching stream data</p>';
    }
}

// Start polling Kinesis
function startKinesisPolling() {
    // Poll every 5 seconds
    kinesisPollingInterval = setInterval(refreshKinesisOutput, 5000);
}

// Stop polling Kinesis
function stopKinesisPolling() {
    if (kinesisPollingInterval) {
        clearInterval(kinesisPollingInterval);
        kinesisPollingInterval = null;
    }
}

// Add entry to activity log
function addLogEntry(message, type = 'info') {
    const log = document.getElementById('activity-log');
    const timestamp = new Date().toLocaleTimeString();
    
    const entry = document.createElement('div');
    entry.className = `log-entry ${type}`;
    entry.innerHTML = `
        <span class="timestamp">[${timestamp}]</span>
        <span class="message">${message}</span>
    `;
    
    log.insertBefore(entry, log.firstChild);
    
    // Keep only last 50 entries
    while (log.children.length > 50) {
        log.removeChild(log.lastChild);
    }
}

// Clean up on page unload
window.addEventListener('beforeunload', function() {
    stopKinesisPolling();
});
