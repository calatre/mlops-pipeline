"""
Ride data structure for taxi trip events
"""
from dataclasses import dataclass
from datetime import datetime
from typing import Optional, Dict, Any
import json


@dataclass
class Ride:
    """Represents a single taxi ride event"""
    
    PULocationID: int
    DOLocationID: int
    trip_distance: float
    ride_id: Optional[str] = None
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert ride to dictionary for JSON serialization"""
        return {
            'ride_id': self.ride_id,
            'PULocationID': self.PULocationID,
            'DOLocationID': self.DOLocationID,
            'trip_distance': self.trip_distance,
            'timestamp': datetime.utcnow().isoformat()
        }
    
    def to_json(self) -> str:
        """Convert ride to JSON string"""
        return json.dumps(self.to_dict())
    
    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> 'Ride':
        """Create Ride from dictionary"""
        return cls(
            ride_id=data.get('ride_id'),
            PULocationID=int(data['PULocationID']),
            DOLocationID=int(data['DOLocationID']),
            trip_distance=float(data['trip_distance'])
        )
    
    @classmethod
    def from_json(cls, json_str: str) -> 'Ride':
        """Create Ride from JSON string"""
        data = json.loads(json_str)
        return cls.from_dict(data)


def create_sample_ride() -> Ride:
    """Create a sample ride for testing"""
    import random
    
    return Ride(
        ride_id=f"test_ride_{datetime.now().strftime('%Y%m%d_%H%M%S')}",
        PULocationID=random.randint(1, 265),  # Valid NYC taxi zones
        DOLocationID=random.randint(1, 265),
        trip_distance=round(random.uniform(0.5, 20.0), 2)  # 0.5 to 20 miles
    )


if __name__ == "__main__":
    # Test the Ride class
    sample_ride = create_sample_ride()
    print("Sample ride:", sample_ride)
    print("As JSON:", sample_ride.to_json())
    
    # Test serialization/deserialization
    json_str = sample_ride.to_json()
    reconstructed_ride = Ride.from_json(json_str)
    print("Reconstructed:", reconstructed_ride)
