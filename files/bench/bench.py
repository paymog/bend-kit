hash_value = 2166136261
with open("bench/fixture.bin", "rb") as source:
    while chunk := source.read(16384):
        for byte in chunk:
            hash_value = ((hash_value ^ byte) * 16777619) & 0xFFFFFFFF
print(hash_value)
