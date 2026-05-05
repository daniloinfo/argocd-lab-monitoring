import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate, Trend } from 'k6/metrics';

// Custom metrics
export let errorRate = new Rate('errors');
export let responseTime = new Trend('response_time');
export let requestCount = new Rate('requests');

// Test configuration
export let options = {
    stages: [
        { duration: '10s', target: __ENV.VUS || 10 },
        { duration: __ENV.DURATION || '30s', target: __ENV.VUS || 10 },
        { duration: '10s', target: 0 },
    ],
    thresholds: {
        http_req_duration: ['p(95)<500'],
        http_req_failed: ['rate<0.1'],
        errors: ['rate<0.1'],
    },
};

// Test endpoints - these should be accessible via port-forward
const endpoints = [
    'http://localhost:8081/actuator/health',
    'http://localhost:8081/actuator/info',
    'http://localhost:8081/hello',
    'http://localhost:8082/actuator/health',
    'http://localhost:8082/actuator/info',
    'http://localhost:8082/hello',
];

export default function () {
    // Test each endpoint
    for (let endpoint of endpoints) {
        let response = http.get(endpoint, {
            timeout: '10s',
        });
        
        let success = check(response, {
            'status is 200': (r) => r.status === 200,
            'response time < 500ms': (r) => r.timings.duration < 500,
            'response time < 1000ms': (r) => r.timings.duration < 1000,
        });
        
        errorRate.add(!success);
        responseTime.add(response.timings.duration);
        requestCount.add(1);
        
        // Small delay between requests
        sleep(0.1);
    }
}

export function handleSummary(data) {
    return {
        'performance-summary.json': JSON.stringify(data, null, 2),
        stdout: textSummary(data, { indent: ' ', enableColors: true }),
    };
}
