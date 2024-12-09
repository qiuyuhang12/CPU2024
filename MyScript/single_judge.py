import sys
import subprocess

def main():
    if len(sys.argv) != 2:
        print("Usage: ./single_judge.py <argument>")
        sys.exit(1)
    
    argument = sys.argv[1]
    # print(f"Argument received: {argument}")

    # 构建命令
    command = f"make run_fpga name={argument}"
    # print(f"Command to execute: {command}")
    
    # 执行命令
    try:
        # result = 
        result = subprocess.run(command, shell=True, check=True, text=True)
        # print(result.stdout)
        # print(result.stdout)
    except subprocess.CalledProcessError as e:
        print(f"Command failed with error: {e.stderr}")
        sys.exit(1)
    
    # 比较文件
    try:
        with open("testspace/your_output", "r") as your_output, open("testspace/test.ans", "r") as test_ans:
            if your_output.read() == test_ans.read():
                print(argument,"\033[92m is correct\033[0m")
            else:
                print(argument,"\033[91m is wrong\033[0m")
    except FileNotFoundError as e:
        print(f"File not found: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()