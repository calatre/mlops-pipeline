"""
Event generator for creating sample events for the MLOps pipeline
"""
import random
import json
from datetime import datetime, timedelta
from typing import Dict, Any, List
import uuid

class EventGenerator:
    """Simple event generator for creating sample events"""
    
    def __init__(self):
        self.event_types = [
            'user_login',
            'page_view',
            'button_click',
            'form_submission',
            'api_call',
            'model_prediction',
            'data_upload'
        ]
        
        self.user_ids = [f"user_{i}" for i in range(1, 101)]
        self.model_versions = ['v1.0', 'v1.1', 'v1.2', 'v2.0']
        
    def generate_event(self, event_type: str = None) -> Dict[str, Any]:
        """
        Generate a single event
        
        Args:
            event_type: Specific event type to generate (optional)
            
        Returns:
            Event dictionary
        """
        if event_type is None:
            event_type = random.choice(self.event_types)
        
        event = {
            'event_id': str(uuid.uuid4()),
            'event_type': event_type,
            'timestamp': datetime.now().isoformat(),
            'user_id': random.choice(self.user_ids)
        }
        
        # Add event-specific data
        if event_type == 'user_login':
            event['data'] = {
                'ip_address': f"{random.randint(1,255)}.{random.randint(1,255)}.{random.randint(1,255)}.{random.randint(1,255)}",
                'device_type': random.choice(['desktop', 'mobile', 'tablet'])
            }
        elif event_type == 'page_view':
            event['data'] = {
                'page': random.choice(['/home', '/dashboard', '/profile', '/settings']),
                'duration_seconds': random.randint(5, 300)
            }
        elif event_type == 'button_click':
            event['data'] = {
                'button_id': random.choice(['submit_btn', 'cancel_btn', 'save_btn', 'delete_btn']),
                'page': random.choice(['/home', '/dashboard', '/profile'])
            }
        elif event_type == 'form_submission':
            event['data'] = {
                'form_id': random.choice(['contact_form', 'feedback_form', 'settings_form']),
                'fields_count': random.randint(3, 10),
                'success': random.choice([True, False])
            }
        elif event_type == 'api_call':
            event['data'] = {
                'endpoint': random.choice(['/api/users', '/api/data', '/api/models']),
                'method': random.choice(['GET', 'POST', 'PUT', 'DELETE']),
                'response_time_ms': random.randint(50, 2000),
                'status_code': random.choice([200, 201, 400, 404, 500])
            }
        elif event_type == 'model_prediction':
            event['data'] = {
                'model_version': random.choice(self.model_versions),
                'prediction_confidence': round(random.uniform(0.5, 0.99), 3),
                'processing_time_ms': random.randint(10, 500),
                'input_features': random.randint(10, 100)
            }
        elif event_type == 'data_upload':
            event['data'] = {
                'file_size_mb': round(random.uniform(0.1, 100.0), 2),
                'file_type': random.choice(['csv', 'json', 'parquet', 'txt']),
                'upload_time_seconds': round(random.uniform(0.5, 30.0), 2)
            }
        
        return event
    
    def generate_batch_events(self, count: int = 10, event_type: str = None) -> List[Dict[str, Any]]:
        """
        Generate multiple events
        
        Args:
            count: Number of events to generate
            event_type: Specific event type for all events (optional)
            
        Returns:
            List of event dictionaries
        """
        events = []
        for _ in range(count):
            events.append(self.generate_event(event_type))
        
        return events
    
    def generate_historical_events(self, days_back: int = 7, events_per_day: int = 100) -> List[Dict[str, Any]]:
        """
        Generate historical events for testing
        
        Args:
            days_back: Number of days to generate events for
            events_per_day: Number of events per day
            
        Returns:
            List of event dictionaries
        """
        events = []
        
        for day in range(days_back):
            date = datetime.now() - timedelta(days=day)
            
            for _ in range(events_per_day):
                event = self.generate_event()
                # Adjust timestamp to be within that day
                hour = random.randint(0, 23)
                minute = random.randint(0, 59)
                second = random.randint(0, 59)
                
                event_time = date.replace(hour=hour, minute=minute, second=second)
                event['timestamp'] = event_time.isoformat()
                
                events.append(event)
        
        return sorted(events, key=lambda x: x['timestamp'])
    
    def save_events_to_file(self, events: List[Dict[str, Any]], filename: str):
        """
        Save events to a JSON file
        
        Args:
            events: List of events to save
            filename: Output filename
        """
        with open(filename, 'w') as f:
            json.dump(events, f, indent=2)
        
        print(f"Saved {len(events)} events to {filename}")
