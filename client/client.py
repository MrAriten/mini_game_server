import socket
import sys
import threading
from client_pb2 import Client  # 导入生成的protobuf消息

def send_message(sock, message):
    serialized_message = message.SerializeToString()
    sock.sendall(serialized_message)

def receive_message(sock):
    data = sock.recv(1024)
    #print("接收报文长度："+ str(len(data)))
    if not data:
        return None
    message = Client()
    message.ParseFromString(data)
    return message

def receive_and_print_messages(sock):
    while True:
        try:
            response = receive_message(sock)
            if response:
                output_string = f"{response.first_element},"
                output_string += ",".join(map(str, response.integer_elements))
                if response.optional_string_element:
                    output_string += f",{response.optional_string_element}"
                print(output_string)
        except socket.error as e:
            print(f"Error receiving message: {e}")
            break

def main():
    host = '127.0.0.1'
    port = 8001

    try:
        sock = socket.create_connection((host, port))
        print(f"Connected to {host}:{port}")

        #开启一个线程打印服务器的输出
        thread = threading.Thread(target=receive_and_print_messages, args=(sock,))
        thread.start()

        while True:
            user_input = input()

            if user_input.lower() == 'exit':
                break

            # 创建protobuf消息
            message = Client()
            message.first_element = user_input + '\r\n'
            # 发送消息
            try:
                send_message(sock, message)
            except socket.error as e:
                print(f"Error sending message: {e}")
                break


    except Exception as e:
        print(f"Error: {e}")
    finally:
        sock.close()

if __name__ == "__main__":
    main()
