FROM python:3.12-alpine

# Set work directory
WORKDIR /usr/src/app

# Copy requirements first to leverage Docker layer caching
COPY requirements.txt .



# Install system dependencies
RUN apk add --no-cache libstdc++

# Install Python dependencies
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY app/ .

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD python -c "import sys; sys.exit(0)" || exit 1

# Set the default command
CMD ["python", "run.py"]
