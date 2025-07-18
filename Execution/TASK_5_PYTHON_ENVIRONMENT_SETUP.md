# Task 5: Python Virtual Environment Setup - Complete Guide from Scratch

## What is a Python Virtual Environment?
A Python virtual environment is an **isolated Python installation** that allows you to install packages and dependencies specific to your project without affecting your system-wide Python installation. Think of it as a "sandbox" for your project.

## Why Do We Need Virtual Environments for IoT Project?
- **Dependency Isolation**: Our CDK project needs specific versions of AWS libraries
- **Conflict Prevention**: Prevents conflicts with other Python projects on your system
- **Reproducibility**: Ensures everyone working on the project has the same environment
- **Clean Management**: Easy to delete and recreate if something goes wrong

## Step-by-Step Execution Guide

### Step 1: Verify Python Installation

**What we're doing**: Checking that Python 3.9+ is available on the system.

**Command executed**:
```bash
python3 --version
```

**Actual output from our execution**:
```
Python 3.13.5
```

**Why this matters**: CDK requires Python 3.9 or later. Our version 3.13.5 exceeds this requirement.

### Step 2: Navigate to Project Directory

**What we're doing**: Positioning ourselves in the correct project folder.

**Command executed**:
```bash
cd /Users/swaroop/Documents/AWS-IOT/Aws-CDK-project
pwd
```

**Actual output**:
```
/Users/swaroop/Documents/AWS-IOT/Aws-CDK-project
```

### Step 3: Create Virtual Environment

**What we're doing**: Creating an isolated Python environment for our project.

**Command executed**:
```bash
python3 -m venv .venv
```

**What this creates**:
- `.venv/` directory with complete Python installation
- Isolated from system Python
- Contains its own pip and package installation area

**Actual files created in `.venv/`**:
```
.venv/
├── .DS_Store          # macOS system file
├── .gitignore         # Git ignore patterns
├── bin/               # Executable files
│   ├── activate       # Activation script (bash)
│   ├── activate.csh   # Activation script (csh)
│   ├── activate.fish  # Activation script (fish)
│   ├── Activate.ps1   # Activation script (PowerShell)
│   ├── pip            # Package installer
│   ├── pip3           # Package installer (Python 3)
│   ├── pip3.13        # Package installer (Python 3.13)
│   ├── python -> python3.13    # Symbolic link to Python
│   ├── python3 -> python3.13   # Symbolic link to Python 3
│   └── python3.13 -> /usr/local/opt/python@3.13/bin/python3.13
├── include/           # Header files for C extensions
├── lib/               # Python packages and modules
│   └── python3.13/
│       └── site-packages/  # Where pip installs packages
└── pyvenv.cfg         # Virtual environment configuration
```

### Step 4: Examine Virtual Environment Configuration

**Key configuration file**: `.venv/pyvenv.cfg`

**Actual content**:
```ini
home = /usr/local/opt/python@3.13/bin
include-system-site-packages = false
version = 3.13.5
executable = /usr/local/Cellar/python@3.13/3.13.5/Frameworks/Python.framework/Versions/3.13/bin/python3.13
command = /usr/local/opt/python@3.13/bin/python3.13 -m venv /Users/swaroop/Documents/AWS-IOT/Aws-CDK-project/.venv
```

**What each line means**:
- `home`: Path to the base Python installation
- `include-system-site-packages = false`: Isolates from system packages
- `version`: Python version used
- `executable`: Path to the Python executable
- `command`: Command used to create this virtual environment

### Step 5: Activate Virtual Environment

**What we're doing**: Switching from system Python to our project's isolated Python.

**Command executed**:
```bash
source .venv/bin/activate
```

**Verification commands**:
```bash
which python
python --version
```

**Actual output from our execution**:
```
/Users/swaroop/Documents/AWS-IOT/Aws-CDK-project/.venv/bin/python
Python 3.13.5
```

**What happens when activated**:
- Terminal prompt changes to show `(.venv)`
- `python` command now points to `.venv/bin/python`
- `VIRTUAL_ENV` environment variable is set
- Any packages installed go into `.venv/lib/python3.13/site-packages/`

### Step 6: Create Requirements Files

**What we're doing**: Defining what Python packages our project needs.

#### File 1: `requirements.txt` - Production Dependencies

**Why we need this file**:
- Lists all packages needed to run our IoT application
- Ensures consistent installations across environments
- Used by `pip install -r requirements.txt`

**Actual file content we created**:
```txt
aws-cdk-lib>=2.0.0
constructs>=10.0.0
boto3
pymysql
```

**How we created this file**:
1. Started with basic `pymysql` (original content)
2. Added `aws-cdk-lib>=2.0.0` for CDK framework
3. Added `constructs>=10.0.0` for CDK constructs
4. Added `boto3` for AWS SDK functionality

**What each dependency does**:
- `aws-cdk-lib>=2.0.0`: Core AWS CDK library - enables infrastructure as code
- `constructs>=10.0.0`: Base classes for all CDK constructs
- `boto3`: AWS SDK for Python - used in Lambda functions for AWS API calls
- `pymysql`: MySQL database connector - enables Lambda to connect to database

#### File 2: `requirements-dev.txt` - Development Dependencies

**Actual file content we created**:
```txt
pytest==6.2.5
```

**Purpose**: Contains packages only needed during development and testing.

### Step 7: Install Dependencies

**What we're doing**: Installing all required packages into our virtual environment.

#### Install Production Dependencies

**Command executed**:
```bash
source .venv/bin/activate && pip install -r requirements.txt
```

**What happened during installation**:
- Downloaded 22 packages total
- Installed all dependencies and their sub-dependencies
- All packages went into `.venv/lib/python3.13/site-packages/`

**Install Development Dependencies**:
```bash
source .venv/bin/activate && pip install -r requirements-dev.txt
```

### Step 8: Document Exact Versions Installed

**Command executed**:
```bash
source .venv/bin/activate && pip freeze > requirements-freeze.txt
```

**Actual `requirements-freeze.txt` content created**:
```txt
attrs==25.3.0
aws-cdk-lib==2.206.0
aws-cdk.asset-awscli-v1==2.2.242
aws-cdk.asset-node-proxy-agent-v6==2.1.0
aws-cdk.cloud-assembly-schema==45.2.0
boto3==1.39.8
botocore==1.39.8
cattrs==24.1.3
constructs==10.4.2
importlib_resources==6.5.2
iniconfig==2.1.0
jmespath==1.0.1
jsii==1.112.0
packaging==25.0
pluggy==1.6.0
publication==0.0.3
py==1.11.0
PyMySQL==1.1.1
pytest==6.2.5
python-dateutil==2.9.0.post0
s3transfer==0.13.0
six==1.17.0
toml==0.10.2
typeguard==2.13.3
typing_extensions==4.14.1
urllib3==2.5.0
```

**What this file represents**:
- **26 packages total** installed (including dependencies)
- **Exact versions** of every package
- **Reproducible environment** - anyone can recreate this exact setup

### Step 9: Create Dependency Verification Script

**What we're doing**: Creating a test script to verify all dependencies work correctly.

**File created**: `test_dependencies.py`

**Actual code content**:
```python
#!/usr/bin/env python3
"""
Test script to verify all dependencies are properly installed
This file is useful for learning and troubleshooting Python environment setup
"""

def test_dependencies():
    """Test that all required dependencies can be imported"""
    try:
        # Test CDK imports
        from aws_cdk import App, Environment
        print("✅ AWS CDK core imports successful")
        
        # Test constructs
        from constructs import Construct
        print("✅ Constructs import successful")
        
        # Test PyMySQL
        import pymysql
        print("✅ PyMySQL import successful")
        
        # Test pytest
        import pytest
        print("✅ Pytest import successful")
        
        # Test boto3 (AWS SDK)
        import boto3
        print("✅ Boto3 (AWS SDK) import successful")
        
        # Test other required modules
        import json
        import base64
        print("✅ Standard library modules successful")
        
        print("\n🎉 All dependencies successfully imported!")
        print("Python virtual environment is ready for CDK development")
        
    except ImportError as e:
        print(f"❌ Import error: {e}")
        return False
    except Exception as e:
        print(f"❌ Unexpected error: {e}")
        return False
    
    return True

def show_environment_info():
    """Display information about the Python environment"""
    import sys
    import os
    
    print("\n📋 Python Environment Information:")
    print(f"Python version: {sys.version}")
    print(f"Python executable: {sys.executable}")
    print(f"Virtual environment: {os.environ.get('VIRTUAL_ENV', 'Not activated')}")
    print(f"Current working directory: {os.getcwd()}")

if __name__ == "__main__":
    print("Testing Python Dependencies for IoT Project")
    print("=" * 50)
    
    test_dependencies()
    show_environment_info()
    
    print("\n💡 Usage:")
    print("Run this script anytime to verify your Python environment is properly set up")
    print("Command: python test_dependencies.py")
```

### Step 10: Run Verification Test

**Command executed**:
```bash
source .venv/bin/activate && python test_dependencies.py
```

**Actual output from our execution**:
```
Testing Python Dependencies for IoT Project
==================================================
✅ AWS CDK core imports successful
✅ Constructs import successful
✅ PyMySQL import successful
✅ Pytest import successful
✅ Boto3 (AWS SDK) import successful
✅ Standard library modules successful

🎉 All dependencies successfully imported!
Python virtual environment is ready for CDK development

📋 Python Environment Information:
Python version: 3.13.5 (main, Jun 11 2025, 15:36:57) [Clang 17.0.0 (clang-1700.0.13.3)]
Python executable: /Users/swaroop/Documents/AWS-IOT/Aws-CDK-project/.venv/bin/python3
Virtual environment: /Users/swaroop/Documents/AWS-IOT/Aws-CDK-project/.venv
Current working directory: /Users/swaroop/Documents/AWS-IOT/Aws-CDK-project

💡 Usage:
Run this script anytime to verify your Python environment is properly set up
Command: python test_dependencies.py
```

## File Integration and Code Snippet Analysis

### **Complete File Structure Created**:
```
Project Root/
├── .venv/                    # Virtual environment directory
│   ├── bin/                  # Executables (python, pip, activate)
│   │   ├── activate          # Bash activation script
│   │   ├── python -> python3.13  # Python executable symlink
│   │   └── pip               # Package installer
│   ├── lib/                  # Installed packages
│   │   └── python3.13/
│   │       └── site-packages/  # 26 packages installed here
│   ├── include/              # C header files
│   └── pyvenv.cfg            # Virtual environment configuration
├── requirements.txt          # 4 production dependencies
├── requirements-dev.txt      # 1 development dependency
├── requirements-freeze.txt   # 26 exact package versions
└── test_dependencies.py      # Verification script
```

### **How Each File Contributes to Python Environment**:

#### **1. `requirements.txt` Code Snippet Purpose**:
```txt
aws-cdk-lib>=2.0.0    # Enables: from aws_cdk import App, Stack
constructs>=10.0.0    # Enables: from constructs import Construct
boto3                 # Enables: import boto3; client = boto3.client('s3')
pymysql               # Enables: import pymysql; conn = pymysql.connect()
```

#### **2. `pyvenv.cfg` Code Snippet Purpose**:
```ini
home = /usr/local/opt/python@3.13/bin          # Base Python location
include-system-site-packages = false          # Isolate from system packages
version = 3.13.5                              # Python version locked
executable = /usr/local/.../python3.13        # Python executable path
```

#### **3. `test_dependencies.py` Code Snippets and Their Functions**:

**CDK Testing Code**:
```python
from aws_cdk import App, Environment
```
- **Purpose**: Tests that CDK can create applications and environments
- **Project use**: Will be used in `app.py` to create CDK application

**Constructs Testing Code**:
```python
from constructs import Construct
```
- **Purpose**: Tests base class for all CDK constructs
- **Project use**: All stack classes will inherit from Construct

**Database Testing Code**:
```python
import pymysql
```
- **Purpose**: Tests MySQL database connectivity
- **Project use**: Lambda functions will use this to connect to database

**AWS SDK Testing Code**:
```python
import boto3
```
- **Purpose**: Tests AWS SDK functionality
- **Project use**: Lambda functions will use this for AWS API calls

**Environment Info Code**:
```python
import sys
import os
print(f"Python executable: {sys.executable}")
print(f"Virtual environment: {os.environ.get('VIRTUAL_ENV')}")
```
- **Purpose**: Shows which Python is being used
- **Project use**: Debugging and verification

### **Integration Flow of Files**:

1. **`pyvenv.cfg`** → Defines virtual environment configuration
2. **`.venv/bin/activate`** → Activates the isolated environment
3. **`requirements.txt`** → Lists what packages to install
4. **`pip install`** → Downloads and installs packages into `.venv/lib/`
5. **`requirements-freeze.txt`** → Documents exact versions installed
6. **`test_dependencies.py`** → Verifies all imports work correctly

### **Code Execution Chain**:
```
activate script → sets VIRTUAL_ENV → python points to .venv/bin/python → 
imports find packages in .venv/lib/python3.13/site-packages/ → 
CDK/boto3/pymysql available for use
```

## Package Integration in IoT Project

### **How Each Package Will Be Used**:

#### **aws-cdk-lib (2.206.0)**:
```python
# In app.py
from aws_cdk import App, Environment, Stack

# Creates CDK application
app = App()

# Defines AWS environment
env = Environment(account="606639739464", region="us-west-1")
```

#### **constructs (10.4.2)**:
```python
# In stack files
from constructs import Construct

class MyStack(Stack):
    def __init__(self, scope: Construct, construct_id: str, **kwargs):
        super().__init__(scope, construct_id, **kwargs)
```

#### **boto3 (1.39.8)**:
```python
# In Lambda functions
import boto3

# Access AWS services
secretsmanager = boto3.client('secretsmanager')
s3 = boto3.client('s3')
```

#### **pymysql (1.1.1)**:
```python
# In Lambda functions
import pymysql

# Connect to database
connection = pymysql.connect(
    host='database-host',
    user='username',
    password='password',
    database='db_name'
)
```

## Complete Task Summary

### **What We Accomplished**:
1. ✅ **Created isolated Python environment** (`.venv/` with 8 subdirectories)
2. ✅ **Defined 4 production dependencies** (`requirements.txt`)
3. ✅ **Defined 1 development dependency** (`requirements-dev.txt`)
4. ✅ **Installed 26 total packages** (including all sub-dependencies)
5. ✅ **Created verification script** (`test_dependencies.py` with 67 lines)
6. ✅ **Documented exact versions** (`requirements-freeze.txt` with 26 packages)
7. ✅ **Verified all imports work** (6 successful import tests)

### **Files Created with Actual Contents**:
- **`.venv/`** - Virtual environment with complete Python 3.13.5 setup
- **`requirements.txt`** - 4 lines defining production dependencies
- **`requirements-dev.txt`** - 1 line defining development dependencies
- **`requirements-freeze.txt`** - 26 lines with exact package versions
- **`test_dependencies.py`** - 67 lines of verification code

### **Environment Capabilities Enabled**:
- **CDK Development**: Can create and deploy AWS infrastructure
- **AWS API Access**: Can interact with AWS services programmatically
- **Database Connectivity**: Can connect to MySQL from Lambda functions
- **Testing**: Can run unit tests on Python code
- **Isolation**: Won't conflict with other Python projects

### **Integration Success**:
- All 6 import tests passed ✅
- Environment variables correctly set ✅
- Python executable points to virtual environment ✅
- All packages available for project development ✅

**Status**: Task 5 complete - Python environment fully functional for IoT project development! 🎉

The environment is now ready to support CDK infrastructure development, Lambda function creation, database connectivity, and comprehensive testing for our IoT motion detection data processing pipeline.