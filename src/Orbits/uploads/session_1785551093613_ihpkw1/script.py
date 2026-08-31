def fibonacci_iterative(n):
    """Calculates the n-th Fibonacci number using an efficient iterative approach."""
    if n < 0:
        raise ValueError("El índice debe ser un número entero no negativo.")
    if n == 0:
        return 0
    elif n == 1:
        return 1

    a, b = 0, 1
    for _ in range(2, n + 1):
        a, b = b, a + b
    return b


def fibonacci_sequence(n):
    """Generates the Fibonacci sequence up to n terms."""
    if n <= 0:
        return []
    elif n == 1:
        return [0]

    sequence = [0, 1]
    while len(sequence) < n:
        sequence.append(sequence[-1] + sequence[-2])
    return sequence


if __name__ == "__main__":
    print("--- Calculadora de Fibonacci ---")
    try:
        n_terms = int(
            input("Ingrese la cantidad de términos de Fibonacci a generar: ")
        )
        if n_terms < 0:
            print("Por favor, ingrese un número mayor o igual a 0.")
        else:
            result_sequence = fibonacci_sequence(n_terms)
            print(f"Secuencia de Fibonacci ({n_terms} términos):")
            print(result_sequence)

            if n_terms > 0:
                print(
                    f"El término número {n_terms} es: {result_sequence[-1]}"
                )
    except ValueError:
        print("Entrada inválida. Por favor, ingrese un número entero.")