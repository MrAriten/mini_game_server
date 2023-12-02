import socket
import sys
from client_pb2 import Client  # 导入生成的protobuf消息

def send_message(sock, message):
    serialized_message = message.SerializeToString()
    print(len(serialized_message))
    sock.sendall(serialized_message)

def receive_message(sock):
    data = sock.recv(1024)
    if not data:
        return None
    message = Client()
    message.ParseFromString(data)
    return message

def main():
    host = '127.0.0.1'
    port = 8001

    try:
        sock = socket.create_connection((host, port))
        print(f"Connected to {host}:{port}")

        while True:
            user_input = input("Enter message: ")

            if user_input.lower() == 'exit':
                break

            # 创建protobuf消息
            message = Client()
            message.data = user_input + '\r\n'
            print(len(user_input + '\r\n'))
            

            # 发送消息
            send_message(sock, message)

            # 接收并打印服务器的响应
            response = receive_message(sock)
            print(f"Server response: {response.data}")

    except Exception as e:
        print(f"Error: {e}")
    finally:
        sock.close()

if __name__ == "__main__":
    main()
