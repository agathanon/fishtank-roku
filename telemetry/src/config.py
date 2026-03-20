bind = "0.0.0.0:8080"  
timeout = 30
accesslog = "-"  
errorlog = "-"  

# Worker settings
workers = 2  
worker_tmp_dir = "/app/tmp"
max_requests = 1000
max_requests_jitter = 50
