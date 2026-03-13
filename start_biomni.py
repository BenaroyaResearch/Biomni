#!/usr/bin/env python
"""
Biomni Gradio Demo Startup Script

This script launches the Biomni interactive web interface.
Access the interface at: http://localhost:7860
Default verification code: Biomni2025
"""

import os
import sys
import signal
import atexit
import ssl
import warnings
from dotenv import load_dotenv

# Load environment variables from .env file FIRST before any imports that might need them
load_dotenv(override=True)

# Handle SSL certificate verification issues (e.g., corporate proxies with self-signed certs)
# This must be set before any HTTP clients are initialized
if os.getenv('DISABLE_SSL_VERIFY', 'false').lower() == 'true':
    print("⚠️  SSL verification disabled (DISABLE_SSL_VERIFY=true)")
    
    # Disable SSL warnings
    import urllib3
    urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
    
    # Set SSL context for standard library
    ssl._create_default_https_context = ssl._create_unverified_context
    
    # Patch httpcore ConnectionPool (used by httpx which Anthropic SDK uses)
    import httpcore
    _original_pool_init = httpcore.ConnectionPool.__init__
    _original_async_pool_init = httpcore.AsyncConnectionPool.__init__
    
    def _patched_pool_init(self, *args, **kwargs):
        kwargs['ssl_context'] = ssl._create_unverified_context()
        _original_pool_init(self, *args, **kwargs)
    
    def _patched_async_pool_init(self, *args, **kwargs):
        kwargs['ssl_context'] = ssl._create_unverified_context()
        _original_async_pool_init(self, *args, **kwargs)
    
    httpcore.ConnectionPool.__init__ = _patched_pool_init
    httpcore.AsyncConnectionPool.__init__ = _patched_async_pool_init
    
    # Also patch httpx for good measure
    import httpx
    _original_client_init = httpx.Client.__init__
    _original_async_client_init = httpx.AsyncClient.__init__
    
    def _patched_client_init(self, *args, **kwargs):
        kwargs['verify'] = False
        _original_client_init(self, *args, **kwargs)
    
    def _patched_async_client_init(self, *args, **kwargs):
        kwargs['verify'] = False
        _original_async_client_init(self, *args, **kwargs)
    
    httpx.Client.__init__ = _patched_client_init
    httpx.AsyncClient.__init__ = _patched_async_client_init
    
    print("✓ SSL verification bypassed for httpcore and httpx")

from biomni.agent import A1

# Global reference to demo for cleanup
_demo_instance = None

def cleanup_handler(signum=None, frame=None):
    """Clean up Gradio server on exit."""
    global _demo_instance
    if _demo_instance is not None:
        print("\n🛑 Shutting down Gradio server...")
        try:
            _demo_instance.close()
            print("✅ Server closed successfully")
        except Exception as e:
            print(f"⚠️  Error during cleanup: {e}")
        _demo_instance = None
    
    if signum is not None:
        sys.exit(0)

# Register cleanup handlers
atexit.register(cleanup_handler)
signal.signal(signal.SIGTERM, cleanup_handler)
signal.signal(signal.SIGINT, cleanup_handler)

def main():
    global _demo_instance
    
    print("🧬 Initializing Biomni Agent...")
    print("=" * 60)
    
    # Read configuration from environment variables
    llm_model = os.getenv('BIOMNI_LLM', 'claude-sonnet-4-20250514')
    data_path = os.getenv('BIOMNI_DATA_PATH', '/app/data')
    skip_data_lake = os.getenv('BIOMNI_SKIP_DATA_LAKE', 'false').lower() == 'true'
    
    # Verify API key is loaded
    if llm_model.startswith('gpt') or llm_model.startswith('o1'):
        if not os.getenv('OPENAI_API_KEY'):
            print("❌ ERROR: OPENAI_API_KEY not found in environment")
            print("Please set it in your .env file")
            return
    elif 'claude' in llm_model or 'sonnet' in llm_model:
        if not os.getenv('ANTHROPIC_API_KEY'):
            print("❌ ERROR: ANTHROPIC_API_KEY not found in environment")
            print("Please set it in your .env file")
            return
    
    print(f"📊 LLM Model: {llm_model}")
    print(f"💾 Data Path: {data_path}")
    print(f"⚡ Skip Data Lake: {skip_data_lake}")
    
    # Initialize the agent
    # - path: where data lake files are stored
    # - llm: the language model to use (from BIOMNI_LLM env var)
    # - expected_data_lake_files: set to [] to skip automatic download
    agent_kwargs = {
        'path': data_path,
        'llm': llm_model
    }
    
    # Skip data lake download if requested (faster startup for testing)
    if skip_data_lake:
        agent_kwargs['expected_data_lake_files'] = []
        print("⚠️  Data lake download skipped - some tools may not work")
    
    agent = A1(**agent_kwargs)
    
    print("\n✅ Agent initialized successfully!")
    print("🚀 Launching Gradio interface...")
    print("=" * 60)
    print("📡 Server will be accessible at: http://localhost:7860")
    print("🔐 Verification code: Biomni2025")
    print("=" * 60)
    
    # Launch the Gradio demo with retry logic for port conflicts
    max_retries = 3
    for attempt in range(max_retries):
        try:
            # Launch the Gradio demo
            # - server_name: '0.0.0.0' allows external access
            # - require_verification: True requires the access code
            # - share: False (default) - set to True for public shareable link
            _demo_instance = agent.launch_gradio_demo(
                server_name='0.0.0.0',
                require_verification=True
            )
            break  # Success!
        except OSError as e:
            if "Cannot find empty port" in str(e) and attempt < max_retries - 1:
                print(f"\n⚠️  Port conflict detected (attempt {attempt + 1}/{max_retries})")
                print("🔄 Waiting for port to be released...")
                import time
                time.sleep(3)
                print("🔄 Retrying...")
            else:
                raise  # Re-raise if it's not a port issue or we're out of retries

if __name__ == "__main__":
    main()
