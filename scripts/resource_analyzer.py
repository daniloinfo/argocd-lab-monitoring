#!/usr/bin/env python3

import json
import sys
import os
from datetime import datetime
from typing import Dict, List, Any

class ResourceAnalyzer:
    def __init__(self):
        self.analysis_data = {}
        
    def parse_cpu_value(self, cpu_str: str) -> float:
        """Parse CPU value string to millicores"""
        if not cpu_str or cpu_str == "not-set":
            return 0.0
        
        cpu_str = cpu_str.strip()
        if cpu_str.endswith('m'):
            return float(cpu_str[:-1])
        elif cpu_str.endswith('n'):
            return float(cpu_str[:-1]) / 1000000
        else:
            return float(cpu_str) * 1000
    
    def parse_memory_value(self, memory_str: str) -> int:
        """Parse memory value string to bytes"""
        if not memory_str or memory_str == "not-set":
            return 0
        
        memory_str = memory_str.strip()
        if memory_str.endswith('Ki'):
            return int(memory_str[:-2]) * 1024
        elif memory_str.endswith('Mi'):
            return int(memory_str[:-2]) * 1024 * 1024
        elif memory_str.endswith('Gi'):
            return int(memory_str[:-2]) * 1024 * 1024 * 1024
        elif memory_str.endswith('k'):
            return int(memory_str[:-1]) * 1000
        elif memory_str.endswith('M'):
            return int(memory_str[:-1]) * 1000 * 1000
        elif memory_str.endswith('G'):
            return int(memory_str[:-1]) * 1000 * 1000 * 1000
        else:
            return int(memory_str)
    
    def format_cpu(self, cpu_millicores: float) -> str:
        """Format CPU value for display"""
        if cpu_millicores < 1000:
            return f"{cpu_millicores:.0f}m"
        else:
            return f"{cpu_millicores/1000:.1f}"
    
    def format_memory(self, memory_bytes: int) -> str:
        """Format memory value for display"""
        if memory_bytes < 1024 * 1024:
            return f"{memory_bytes // 1024}Ki"
        elif memory_bytes < 1024 * 1024 * 1024:
            return f"{memory_bytes // (1024 * 1024)}Mi"
        else:
            return f"{memory_bytes // (1024 * 1024 * 1024)}Gi"
    
    def analyze_resource_usage(self, resource_file: str) -> Dict[str, Any]:
        """Analyze resource usage and generate recommendations"""
        with open(resource_file, 'r') as f:
            data = json.load(f)
        
        analysis = {
            "timestamp": datetime.now().isoformat(),
            "namespace": data["namespace"],
            "summary": {
                "total_pods": len(data["pods"]),
                "running_pods": len([p for p in data["pods"] if p["status"] == "Running"]),
                "quarkus_pods": len([p for p in data["pods"] if p["type"] == "Quarkus"]),
                "springboot_pods": len([p for p in data["pods"] if p["type"] == "Spring Boot"]),
                "unknown_pods": len([p for p in data["pods"] if p["type"] == "unknown"]),
            },
            "recommendations": [],
            "pod_analysis": [],
            "resource_summary": {
                "total_cpu_usage": 0,
                "total_memory_usage": 0,
                "total_cpu_requests": 0,
                "total_memory_requests": 0,
                "total_cpu_limits": 0,
                "total_memory_limits": 0,
            }
        }
        
        # Analyze each pod
        for pod in data["pods"]:
            pod_analysis = self._analyze_pod(pod)
            analysis["pod_analysis"].append(pod_analysis)
            
            # Update summary
            analysis["resource_summary"]["total_cpu_usage"] += self.parse_cpu_value(pod["cpu_usage"])
            analysis["resource_summary"]["total_memory_usage"] += self.parse_memory_value(pod["memory_usage"])
            
            if pod["cpu_request"] != "not-set":
                analysis["resource_summary"]["total_cpu_requests"] += self.parse_cpu_value(pod["cpu_request"])
            if pod["memory_request"] != "not-set":
                analysis["resource_summary"]["total_memory_requests"] += self.parse_memory_value(pod["memory_request"])
            if pod["cpu_limit"] != "not-set":
                analysis["resource_summary"]["total_cpu_limits"] += self.parse_cpu_value(pod["cpu_limit"])
            if pod["memory_limit"] != "not-set":
                analysis["resource_summary"]["total_memory_limits"] += self.parse_memory_value(pod["memory_limit"])
        
        # Generate overall recommendations
        analysis["recommendations"] = self._generate_overall_recommendations(analysis)
        
        return analysis
    
    def _analyze_pod(self, pod: Dict[str, Any]) -> Dict[str, Any]:
        """Analyze individual pod"""
        pod_analysis = {
            "name": pod["name"],
            "type": pod["type"],
            "status": pod["status"],
            "current_usage": {
                "cpu": pod["cpu_usage"],
                "memory": pod["memory_usage"],
                "cpu_millicores": self.parse_cpu_value(pod["cpu_usage"]),
                "memory_bytes": self.parse_memory_value(pod["memory_usage"])
            },
            "resource_config": {
                "cpu_request": pod["cpu_request"],
                "cpu_limit": pod["cpu_limit"],
                "memory_request": pod["memory_request"],
                "memory_limit": pod["memory_limit"],
                "cpu_request_millicores": self.parse_cpu_value(pod["cpu_request"]),
                "cpu_limit_millicores": self.parse_cpu_value(pod["cpu_limit"]),
                "memory_request_bytes": self.parse_memory_value(pod["memory_request"]),
                "memory_limit_bytes": self.parse_memory_value(pod["memory_limit"])
            },
            "recommendations": [],
            "efficiency": {
                "cpu_efficiency": 0.0,
                "memory_efficiency": 0.0
            }
        }
        
        # Generate recommendations
        pod_analysis["recommendations"] = self._generate_pod_recommendations(pod_analysis)
        
        # Calculate efficiency
        pod_analysis["efficiency"] = self._calculate_efficiency(pod_analysis)
        
        return pod_analysis
    
    def _generate_pod_recommendations(self, pod_analysis: Dict[str, Any]) -> List[Dict[str, Any]]:
        """Generate recommendations for individual pod"""
        recommendations = []
        
        # CPU recommendations
        if pod_analysis["resource_config"]["cpu_request"] == "not-set":
            current_cpu = pod_analysis["current_usage"]["cpu_millicores"]
            suggested_cpu = max(100, int(current_cpu * 1.5))
            recommendations.append({
                "type": "cpu_request",
                "severity": "high",
                "message": "Set CPU request for predictable performance",
                "suggested_value": f"{suggested_cpu}m",
                "current_value": "not-set",
                "impact": "high"
            })
        
        if pod_analysis["resource_config"]["cpu_limit"] == "not-set":
            current_cpu = pod_analysis["current_usage"]["cpu_millicores"]
            suggested_limit = max(500, int(current_cpu * 2))
            recommendations.append({
                "type": "cpu_limit",
                "severity": "medium",
                "message": "Set CPU limit to prevent resource starvation",
                "suggested_value": f"{suggested_limit}m",
                "current_value": "not-set",
                "impact": "medium"
            })
        
        # Memory recommendations
        if pod_analysis["resource_config"]["memory_request"] == "not-set":
            current_memory = pod_analysis["current_usage"]["memory_bytes"]
            suggested_memory = max(256 * 1024 * 1024, int(current_memory * 1.5))
            recommendations.append({
                "type": "memory_request",
                "severity": "high",
                "message": "Set memory request for predictable performance",
                "suggested_value": self.format_memory(suggested_memory),
                "current_value": "not-set",
                "impact": "high"
            })
        
        if pod_analysis["resource_config"]["memory_limit"] == "not-set":
            current_memory = pod_analysis["current_usage"]["memory_bytes"]
            suggested_limit = max(512 * 1024 * 1024, int(current_memory * 2))
            recommendations.append({
                "type": "memory_limit",
                "severity": "medium",
                "message": "Set memory limit to prevent OOM kills",
                "suggested_value": self.format_memory(suggested_limit),
                "current_value": "not-set",
                "impact": "medium"
            })
        
        # Efficiency recommendations
        cpu_efficiency = pod_analysis["efficiency"]["cpu_efficiency"]
        if cpu_efficiency > 0.8:
            recommendations.append({
                "type": "cpu_optimization",
                "severity": "medium",
                "message": "CPU usage is high, consider optimizing or increasing resources",
                "suggested_value": f"Current efficiency: {cpu_efficiency:.1%}",
                "current_value": pod_analysis["current_usage"]["cpu"],
                "impact": "medium"
            })
        elif cpu_efficiency < 0.2 and pod_analysis["resource_config"]["cpu_request"] != "not-set":
            recommendations.append({
                "type": "cpu_optimization",
                "severity": "low",
                "message": "CPU usage is low, consider reducing requests",
                "suggested_value": f"Current efficiency: {cpu_efficiency:.1%}",
                "current_value": pod_analysis["current_usage"]["cpu"],
                "impact": "low"
            })
        
        memory_efficiency = pod_analysis["efficiency"]["memory_efficiency"]
        if memory_efficiency > 0.8:
            recommendations.append({
                "type": "memory_optimization",
                "severity": "medium",
                "message": "Memory usage is high, consider optimizing or increasing resources",
                "suggested_value": f"Current efficiency: {memory_efficiency:.1%}",
                "current_value": pod_analysis["current_usage"]["memory"],
                "impact": "medium"
            })
        elif memory_efficiency < 0.2 and pod_analysis["resource_config"]["memory_request"] != "not-set":
            recommendations.append({
                "type": "memory_optimization",
                "severity": "low",
                "message": "Memory usage is low, consider reducing requests",
                "suggested_value": f"Current efficiency: {memory_efficiency:.1%}",
                "current_value": pod_analysis["current_usage"]["memory"],
                "impact": "low"
            })
        
        # Framework-specific recommendations
        if pod_analysis["type"] == "Quarkus":
            recommendations.append({
                "type": "framework_specific",
                "severity": "low",
                "message": "Quarkus is optimized for low memory usage",
                "suggested_value": "Consider using smaller memory limits (128Mi-256Mi)",
                "current_value": pod_analysis["resource_config"]["memory_limit"],
                "impact": "low"
            })
        elif pod_analysis["type"] == "Spring Boot":
            recommendations.append({
                "type": "framework_specific",
                "severity": "low",
                "message": "Spring Boot requires more memory for startup",
                "suggested_value": "Consider larger memory limits (512Mi-1Gi)",
                "current_value": pod_analysis["resource_config"]["memory_limit"],
                "impact": "low"
            })
        
        return recommendations
    
    def _calculate_efficiency(self, pod_analysis: Dict[str, Any]) -> Dict[str, float]:
        """Calculate resource efficiency"""
        cpu_efficiency = 0.0
        memory_efficiency = 0.0
        
        # CPU efficiency
        if pod_analysis["resource_config"]["cpu_request_millicores"] > 0:
            cpu_efficiency = pod_analysis["current_usage"]["cpu_millicores"] / pod_analysis["resource_config"]["cpu_request_millicores"]
        
        # Memory efficiency
        if pod_analysis["resource_config"]["memory_request_bytes"] > 0:
            memory_efficiency = pod_analysis["current_usage"]["memory_bytes"] / pod_analysis["resource_config"]["memory_request_bytes"]
        
        return {
            "cpu_efficiency": min(cpu_efficiency, 1.0),
            "memory_efficiency": min(memory_efficiency, 1.0)
        }
    
    def _generate_overall_recommendations(self, analysis: Dict[str, Any]) -> List[Dict[str, Any]]:
        """Generate overall recommendations"""
        recommendations = []
        
        # Check if any pods lack resource requests/limits
        pods_without_requests = [p for p in analysis["pod_analysis"] if p["resource_config"]["cpu_request"] == "not-set" or p["resource_config"]["memory_request"] == "not-set"]
        if pods_without_requests:
            recommendations.append({
                "type": "resource_requests",
                "severity": "high",
                "message": f"{len(pods_without_requests)} pods missing resource requests",
                "suggested_value": "Set resource requests for all pods",
                "impact": "high",
                "affected_pods": [p["name"] for p in pods_without_requests]
            })
        
        # Check resource efficiency
        low_efficiency_pods = [p for p in analysis["pod_analysis"] if p["efficiency"]["cpu_efficiency"] < 0.2 or p["efficiency"]["memory_efficiency"] < 0.2]
        if low_efficiency_pods:
            recommendations.append({
                "type": "resource_efficiency",
                "severity": "medium",
                "message": f"{len(low_efficiency_pods)} pods with low resource efficiency",
                "suggested_value": "Review and optimize resource allocation",
                "impact": "medium",
                "affected_pods": [p["name"] for p in low_efficiency_pods]
            })
        
        # Framework-specific recommendations
        if analysis["summary"]["quarkus_pods"] > 0:
            recommendations.append({
                "type": "framework_optimization",
                "severity": "low",
                "message": "Quarkus applications detected",
                "suggested_value": "Consider using smaller memory limits (128Mi-256Mi)",
                "impact": "low"
            })
        
        if analysis["summary"]["springboot_pods"] > 0:
            recommendations.append({
                "type": "framework_optimization",
                "severity": "low",
                "message": "Spring Boot applications detected",
                "suggested_value": "Consider larger memory limits (512Mi-1Gi)",
                "impact": "low"
            })
        
        return recommendations
    
    def generate_html_report(self, resource_file: str, analysis_file: str, load_test_file: str = None) -> str:
        """Generate comprehensive HTML report"""
        # Load data
        with open(resource_file, 'r') as f:
            resource_data = json.load(f)
        
        with open(analysis_file, 'r') as f:
            analysis_data = json.load(f)
        
        load_test_data = {}
        if load_test_file and os.path.exists(load_test_file):
            try:
                with open(load_test_file, 'r') as f:
                    load_test_data = json.load(f)
            except:
                pass
        
        # Generate HTML
        html_content = self._generate_html_content(resource_data, analysis_data, load_test_data)
        
        # Save HTML file
        output_file = f"performance-analysis-{datetime.now().strftime('%Y%m%d-%H%M%S')}.html"
        with open(output_file, 'w') as f:
            f.write(html_content)
        
        return output_file
    
    def _generate_html_content(self, resource_data: Dict, analysis_data: Dict, load_test_data: Dict) -> str:
        """Generate HTML content"""
        # Generate pod cards
        pod_cards = ""
        for pod in analysis_data["pod_analysis"]:
            pod_type_class = pod["type"].lower().replace(" ", "")
            if pod_type_class == "springboot":
                pod_type_class = "springboot"
            elif pod_type_class == "unknown":
                pod_type_class = "unknown"
            
            pod_cards += f'''
    <div class="pod-card">
        <div class="pod-header">
            <div class="pod-name">{pod["name"]}</div>
            <div class="pod-type {pod_type_class}">{pod["type"]}</div>
        </div>
        
        <div class="resource-grid">
            <div class="resource-item">
                <div class="resource-label">CPU Usage</div>
                <div class="resource-value">{pod["current_usage"]["cpu"]}</div>
            </div>
            <div class="resource-item">
                <div class="resource-label">Memory Usage</div>
                <div class="resource-value">{pod["current_usage"]["memory"]}</div>
            </div>
            <div class="resource-item">
                <div class="resource-label">CPU Request</div>
                <div class="resource-value">{pod["resource_config"]["cpu_request"]}</div>
            </div>
            <div class="resource-item">
                <div class="resource-label">CPU Limit</div>
                <div class="resource-value">{pod["resource_config"]["cpu_limit"]}</div>
            </div>
            <div class="resource-item">
                <div class="resource-label">Memory Request</div>
                <div class="resource-value">{pod["resource_config"]["memory_request"]}</div>
            </div>
            <div class="resource-item">
                <div class="resource-label">Memory Limit</div>
                <div class="resource-value">{pod["resource_config"]["memory_limit"]}</div>
            </div>
        </div>
        
        <div class="efficiency-grid">
            <div class="resource-item">
                <div class="resource-label">CPU Efficiency</div>
                <div class="resource-value">{pod["efficiency"]["cpu_efficiency"]:.1%}</div>
            </div>
            <div class="resource-item">
                <div class="resource-label">Memory Efficiency</div>
                <div class="resource-value">{pod["efficiency"]["memory_efficiency"]:.1%}</div>
            </div>
        </div>
        
        <div class="recommendations">
            <h4>Recommendations:</h4>'''
            
            for rec in pod["recommendations"]:
                pod_cards += f'''
            <div class="recommendation {rec["severity"]}">
                <div class="recommendation-title">{rec["type"].replace("_", " ").title()}</div>
                <div class="recommendation-message">{rec["message"]}</div>
                <div class="recommendation-suggestion">Suggested: {rec["suggested_value"]}</div>
                <div class="recommendation-impact">Impact: {rec["impact"]}</div>
            </div>'''
            
            pod_cards += '''
        </div>
    </div>'''
        
        # Generate load test section
        load_test_section = ""
        if load_test_data:
            load_test_section = '''
    <div class="section">
        <div class="section-header">Load Test Results</div>
        <div class="section-content">
            <div class="load-test-results">
                <h4>Test Configuration:</h4>
                <div class="metric">
                    <span class="metric-name">Virtual Users:</span>
                    <span class="metric-value">{vus}</span>
                </div>
                <div class="metric">
                    <span class="metric-name">Duration:</span>
                    <span class="metric-value">{duration}</span>
                </div>
                
                <h4>Performance Metrics:</h4>'''
            
            if "metrics" in load_test_data:
                for metric_name, metric_value in load_test_data["metrics"].items():
                    if isinstance(metric_value, dict) and "value" in metric_value:
                        load_test_section += f'''
                <div class="metric">
                    <span class="metric-name">{metric_name}:</span>
                    <span class="metric-value">{metric_value["value"]}</span>
                </div>'''
            
            load_test_section += '''
            </div>
        </div>
    </div>'''
        
        # Generate overall recommendations section
        overall_recommendations = ""
        if analysis_data["recommendations"]:
            overall_recommendations = '''
    <div class="section">
        <div class="section-header">Overall Recommendations</div>
        <div class="section-content">
            <div class="recommendations">'''
            
            for rec in analysis_data["recommendations"]:
                overall_recommendations += f'''
            <div class="recommendation {rec["severity"]}">
                <div class="recommendation-title">{rec["type"].replace("_", " ").title()}</div>
                <div class="recommendation-message">{rec["message"]}</div>
                <div class="recommendation-suggestion">Suggested: {rec["suggested_value"]}</div>
                <div class="recommendation-impact">Impact: {rec["impact"]}</div>
            </div>'''
            
            overall_recommendations += '''
            </div>
        </div>
    </div>'''
        
        # Resource summary section
        resource_summary = f'''
    <div class="section">
        <div class="section-header">Resource Summary</div>
        <div class="section-content">
            <div class="resource-grid">
                <div class="resource-item">
                    <div class="resource-label">Total CPU Usage</div>
                    <div class="resource-value">{self.format_cpu(analysis_data["resource_summary"]["total_cpu_usage"])}</div>
                </div>
                <div class="resource-item">
                    <div class="resource-label">Total Memory Usage</div>
                    <div class="resource-value">{self.format_memory(analysis_data["resource_summary"]["total_memory_usage"])}</div>
                </div>
                <div class="resource-item">
                    <div class="resource-label">Total CPU Requests</div>
                    <div class="resource-value">{self.format_cpu(analysis_data["resource_summary"]["total_cpu_requests"])}</div>
                </div>
                <div class="resource-item">
                    <div class="resource-label">Total Memory Requests</div>
                    <div class="resource-value">{self.format_memory(analysis_data["resource_summary"]["total_memory_requests"])}</div>
                </div>
                <div class="resource-item">
                    <div class="resource-label">Total CPU Limits</div>
                    <div class="resource-value">{self.format_cpu(analysis_data["resource_summary"]["total_cpu_limits"])}</div>
                </div>
                <div class="resource-item">
                    <div class="resource-label">Total Memory Limits</div>
                    <div class="resource-value">{self.format_memory(analysis_data["resource_summary"]["total_memory_limits"])}</div>
                </div>
            </div>
        </div>
    </div>'''
        
        # Complete HTML template
        html_template = f'''<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Performance Analysis Report</title>
    <style>
        * {{
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }}
        
        body {{
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            line-height: 1.6;
            color: #333;
            background-color: #f5f5f5;
        }}
        
        .container {{
            max-width: 1200px;
            margin: 0 auto;
            padding: 20px;
        }}
        
        .header {{
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 30px;
            border-radius: 10px;
            margin-bottom: 30px;
            box-shadow: 0 4px 6px rgba(0,0,0,0.1);
        }}
        
        .header h1 {{
            font-size: 2.5em;
            margin-bottom: 10px;
        }}
        
        .header p {{
            font-size: 1.2em;
            opacity: 0.9;
        }}
        
        .summary-cards {{
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 20px;
            margin-bottom: 30px;
        }}
        
        .card {{
            background: white;
            padding: 25px;
            border-radius: 10px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
            transition: transform 0.3s ease;
        }}
        
        .card:hover {{
            transform: translateY(-5px);
        }}
        
        .card h3 {{
            color: #667eea;
            margin-bottom: 15px;
            font-size: 1.3em;
        }}
        
        .card .value {{
            font-size: 2em;
            font-weight: bold;
            color: #333;
            margin-bottom: 10px;
        }}
        
        .card .description {{
            color: #666;
            font-size: 0.9em;
        }}
        
        .section {{
            background: white;
            margin-bottom: 30px;
            border-radius: 10px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
            overflow: hidden;
        }}
        
        .section-header {{
            background: #667eea;
            color: white;
            padding: 20px;
            font-size: 1.5em;
            font-weight: bold;
        }}
        
        .section-content {{
            padding: 30px;
        }}
        
        .pod-grid {{
            display: grid;
            gap: 20px;
        }}
        
        .pod-card {{
            border: 1px solid #e0e0e0;
            border-radius: 8px;
            padding: 20px;
            background: #fafafa;
        }}
        
        .pod-header {{
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 15px;
        }}
        
        .pod-name {{
            font-weight: bold;
            font-size: 1.2em;
            color: #333;
        }}
        
        .pod-type {{
            padding: 5px 10px;
            border-radius: 20px;
            font-size: 0.8em;
            font-weight: bold;
        }}
        
        .quarkus {{
            background: #4caf50;
            color: white;
        }}
        
        .springboot {{
            background: #ff9800;
            color: white;
        }}
        
        .unknown {{
            background: #9e9e9e;
            color: white;
        }}
        
        .resource-grid {{
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 15px;
            margin: 15px 0;
        }}
        
        .resource-item {{
            padding: 10px;
            background: white;
            border-radius: 5px;
            border-left: 4px solid #667eea;
        }}
        
        .resource-label {{
            font-weight: bold;
            color: #666;
            margin-bottom: 5px;
        }}
        
        .resource-value {{
            font-size: 1.1em;
            color: #333;
        }}
        
        .efficiency-grid {{
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 15px;
            margin: 15px 0;
        }}
        
        .recommendations {{
            margin-top: 20px;
        }}
        
        .recommendation {{
            padding: 15px;
            margin: 10px 0;
            border-radius: 5px;
            border-left: 4px solid;
        }}
        
        .high {{
            background: #ffebee;
            border-left-color: #f44336;
        }}
        
        .medium {{
            background: #fff3e0;
            border-left-color: #ff9800;
        }}
        
        .low {{
            background: #f3e5f5;
            border-left-color: #9c27b0;
        }}
        
        .recommendation-title {{
            font-weight: bold;
            margin-bottom: 5px;
        }}
        
        .recommendation-message {{
            margin-bottom: 10px;
        }}
        
        .recommendation-suggestion {{
            font-style: italic;
            color: #666;
        }}
        
        .recommendation-impact {{
            font-weight: bold;
            color: #333;
        }}
        
        .load-test-results {{
            margin-top: 20px;
        }}
        
        .metric {{
            display: flex;
            justify-content: space-between;
            padding: 10px;
            background: #f5f5f5;
            margin: 5px 0;
            border-radius: 5px;
        }}
        
        .metric-name {{
            font-weight: bold;
        }}
        
        .metric-value {{
            color: #667eea;
            font-weight: bold;
        }}
        
        .footer {{
            text-align: center;
            padding: 20px;
            color: #666;
            margin-top: 30px;
        }}
        
        @media (max-width: 768px) {{
            .container {{
                padding: 10px;
            }}
            
            .header h1 {{
                font-size: 2em;
            }}
            
            .summary-cards {{
                grid-template-columns: 1fr;
            }}
        }}
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>Performance Analysis Report</h1>
            <p>Namespace: {resource_data['namespace']} | Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}</p>
        </div>
        
        <div class="summary-cards">
            <div class="card">
                <h3>Total Pods</h3>
                <div class="value">{analysis_data['summary']['total_pods']}</div>
                <div class="description">Pods in namespace</div>
            </div>
            <div class="card">
                <h3>Running Pods</h3>
                <div class="value">{analysis_data['summary']['running_pods']}</div>
                <div class="description">Currently running</div>
            </div>
            <div class="card">
                <h3>Quarkus Apps</h3>
                <div class="value">{analysis_data['summary']['quarkus_pods']}</div>
                <div class="description">Quarkus applications</div>
            </div>
            <div class="card">
                <h3>Spring Boot Apps</h3>
                <div class="value">{analysis_data['summary']['springboot_pods']}</div>
                <div class="description">Spring Boot applications</div>
            </div>
        </div>
        
        {resource_summary}
        
        <div class="section">
            <div class="section-header">Pod Analysis</div>
            <div class="section-content">
                <div class="pod-grid">
                    {pod_cards}
                </div>
            </div>
        </div>
        
        {overall_recommendations}
        
        {load_test_section}
        
        <div class="footer">
            <p>Generated by Performance Analyzer Script | Argo CD Lab</p>
        </div>
    </div>
</body>
</html>'''
        
        return html_template

def main():
    if len(sys.argv) < 3:
        print("Usage: python3 resource_analyzer.py <resource_file> <analysis_file> [load_test_file]")
        sys.exit(1)
    
    resource_file = sys.argv[1]
    analysis_file = sys.argv[2]
    load_test_file = sys.argv[3] if len(sys.argv) > 3 else None
    
    analyzer = ResourceAnalyzer()
    
    # Analyze resources
    analysis = analyzer.analyze_resource_usage(resource_file)
    
    # Save analysis
    with open(analysis_file, 'w') as f:
        json.dump(analysis, f, indent=2)
    
    print(f"Analysis saved to: {analysis_file}")
    
    # Generate HTML report
    html_report = analyzer.generate_html_report(resource_file, analysis_file, load_test_file)
    print(f"HTML report generated: {html_report}")

if __name__ == "__main__":
    main()
