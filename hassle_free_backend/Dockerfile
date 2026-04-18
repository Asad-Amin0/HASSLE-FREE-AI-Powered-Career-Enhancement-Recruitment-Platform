# Use an official Python runtime as a parent image
FROM python:3.10-slim

# Set the working directory in the container
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    curl \
    software-properties-common \
    && rm -rf /var/lib/apt/lists/*

# Copy the requirements file into the container
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Download NLP models and tools
RUN python -m spacy download en_core_web_sm
RUN python -m nltk.downloader stopwords punkt

# Copy the rest of the application code
COPY . .

# Expose the port the app runs on
EXPOSE 5002

# Define the command to run the application
# Use gunicorn for production instead of Flask's built-in server
CMD ["python", "main.py"]
