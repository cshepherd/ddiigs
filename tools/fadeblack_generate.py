import math

def generate_fade_black_gamma(gamma=1.6):
    table = []

    for orig in range(16):
        for step in range(16):
            t = step / 15.0  # 0 → 1

            # Apply gamma curve
            fade = math.pow(1.0 - t, gamma)

            value = orig * fade

            value = int(round(value))
            value = max(0, min(15, value))

            table.append(value)

    return table


def emit_asm(table, label="fadeBlack"):
    print(f"{label}:")
    for i in range(0, 256, 16):
        row = table[i:i+16]
        bytes_str = ", ".join(f"${v:02X}" for v in row)
        print(f"    db {bytes_str}")


if __name__ == "__main__":
    table = generate_fade_black_gamma(gamma=1.6)
    emit_asm(table)