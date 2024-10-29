import subprocess

subprocess.run(["python", "-m", "prisma", "migrate", "deploy"])
subprocess.run(["python", "main.py"])
