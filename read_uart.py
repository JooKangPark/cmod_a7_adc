import serial

print("Start reading")
ser = serial.Serial('/dev/ttyUSB1', 115200)

while True:
    b = ser.read(1)
    print(f"{b[0]:08b}")
