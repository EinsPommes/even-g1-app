# G1 Smart Glasses Protocol Guide

This document describes the protocol used to communicate with Even Reality G1 Smart Glasses via Bluetooth Low Energy (BLE).

## BLE Service and Characteristics

The G1 glasses use the following BLE service and characteristics:

- **Service UUID**: `6E400001-B5A3-F393-E0A9-E50E24DCCA9E` (Nordic UART Service)
- **TX Characteristic**: `6E400002-B5A3-F393-E0A9-E50E24DCCA9E` (Write, WriteWithoutResponse)
  - Used to send data to the glasses
- **RX Characteristic**: `6E400003-B5A3-F393-E0A9-E50E24DCCA9E` (Notify)
  - Used to receive data from the glasses

## Packet Structure

Based on observed communication, the G1 glasses use a packet-based protocol with the following structure:

### Packet Types

Each packet starts with a type identifier byte:

| Type ID (hex) | Description           | Purpose                                   |
|---------------|-----------------------|-------------------------------------------|
| 0x22          | Command Packet        | Control commands to/from the glasses      |
| 0x29          | Status Packet         | Status information from the glasses       |
| 0x2B          | Heartbeat Packet      | Regular heartbeat signals                 |
| 0x2C          | Battery Packet        | Battery level information                 |
| 0x06          | Configuration Packet  | Configuration settings                    |
| 0xF1          | Data Stream Packet    | Streaming data (sensors, etc.)            |
| 0xF5          | Event Packet          | Event notifications                       |
| 0x48          | Text Response Packet  | Response to text messages                 |

### Common Packet Formats

#### Command Packet (0x22)
```
0x22 <length> <command_id> [data...]
```

#### Status Packet (0x29)
```
0x29 <status_type> <status_value>
```

#### Heartbeat Packet (0x2B)
```
0x2B <heartbeat_id> <heartbeat_value> [data...]
```

#### Battery Packet (0x2C)
```
0x2C <battery_id> <battery_level> <timestamp_bytes...>
```

#### Configuration Packet (0x06)
```
0x06 <length> <config_id> [config_data...]
```

#### Event Packet (0xF5)
```
0xF5 <event_id> [event_data...]
```

#### Text Response Packet (0x48)
Normal response:
```
0x48 <text_data...>
```

Error response:
```
0x48 0xCA <error_message...>
```

## Sending Text to Glasses

To send text to the glasses:

1. Encode the text as UTF-8
2. Add a newline character (`\n`) at the end
3. If text is longer than 20 bytes, split into multiple packets
4. Send to the TX characteristic (6E400002-B5A3-F393-E0A9-E50E24DCCA9E)
5. Use WriteWithoutResponse for best performance

Example:
```
"Hello" → 0x48 0x65 0x6C 0x6C 0x6F 0x0A
```

## Error Handling

When sending text, the glasses may respond with an error packet:
```
0x48 0xCA <error_message...>
```

Common error messages:
- `error post req.` - Error in processing the request

## Battery Information

Battery information is sent in packets starting with 0x2C:
```
0x2C <battery_id> <battery_level> <timestamp_bytes...>
```

The battery level is a percentage (0-100).

## Observed Packet Examples

### Heartbeat Packet
```
2B 69 0A 06 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
```

### Battery Packet
```
2C 66 5A 5B E5 8A 21 01 06 04 01 06 04 00 00 00 00 00 00 00
```

### Status Packet
```
29 65 00 01 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
```

### Configuration Packet
```
06 07 00 B9 06 00
```

### Error Response
```
48 CA 65 72 72 6F 72 20 70 6F 73 74 20 72 65 71 2E 00 00 00
```
Decoded: "error post req."

## Best Practices

1. **Chunking**: Always split messages larger than 20 bytes into multiple packets
2. **Delay**: Add a small delay (3ms) between packets when sending chunked data
3. **Newline**: Always append a newline character (`\n`) to text messages
4. **Error Handling**: Check for error responses after sending commands
5. **Battery Monitoring**: Parse battery packets to display battery level to users

## Implementation Notes

For optimal communication with G1 glasses:

1. Use WriteWithoutResponse for sending data
2. Enable notifications on the RX characteristic
3. Process all packet types, especially battery and error responses
4. Keep track of connection state and reconnect automatically when needed
5. Implement proper error handling for failed operations
