# filepath: /opt/mlops-frontend/Dockerfile
FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --upgrade pip && pip install -r requirements.txt

COPY . .

EXPOSE 5000

# Use gunicorn for production, fallback to flask for dev
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "app:app"]