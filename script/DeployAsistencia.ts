import hre from "hardhat"; //// Importa el entorno de ejecución de Hardhat. Este objeto (hre) me da acceso a todas las herramientas de Hardhat en mi script, como ethers.js para desplegar contratos, consultar cuentas, y configurar redes. Es necesario si quiero usar funcionalidades de Hardhat directamente en un archivo que ejecuto con Node.js (y no con `npx hardhat run`).
import { keccak256, stringToBytes } from "viem"; // Importa dos funciones de la librería "viem". `keccak256` me permite calcular el hash de un dato (muy usado en Ethereum para direcciones, identificadores, etc.), y `stringToBytes` convierte un texto (string) en una secuencia de bytes, que es el formato que entiende la red. Son útiles cuando quiero preparar datos para usarlos en contratos inteligentes o hacer comparaciones seguras.

const alumno1 = "0x70997970C51812dc3A010C7d01b50e0d17dc79C8" // Guarda la dirección Ethereum del primer alumno. Sirve para identificarlo y autorizarlo en el contrato.
const alumno2 = "0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC" // Guarda la dirección Ethereum del segundo alumno. Igual que la anterior, representa a otro participante autorizado.
const palabraSecreta = "solidity"  // Define una palabra clave que puede usarse como contraseña o código dentro del contrato. Puede ser transformada a bytes o hasheada para mayor seguridad.
const duracionSesion = 3   // Indica la duración de una sesión (por ejemplo, en horas o bloques, según cómo lo interprete el contrato). Puede servir para limitar el tiempo de acceso o validez de una acción.

async function main() { // Declara una función asíncrona principal donde se ejecutará el código. Es común en scripts de despliegue o interacción con contratos para poder usar `await`.
  const [profesor] = await hre.viem.getWalletClients()  // Obtiene la lista de wallets disponibles en el entorno (como cuentas simuladas en Hardhat) y guarda la primera (el "profesor") para usarla como firmante en transacciones.
  const publicClient = await hre.viem.getPublicClient() // Crea un cliente público para leer información de la blockchain (como estados de contratos, eventos, etc.), sin necesidad de firmar transacciones.

  //Deployar el contrato
  const contratoAsistencia = await hre.viem.deployContract("Asistencia",["AsistenciaToken","AST",profesor.account.address])
  // Despliega un contrato llamado "Asistencia" usando la herramienta de Hardhat-Viem.
// Le pasa tres argumentos al constructor del contrato:
// - "AsistenciaToken" es el nombre del token (como un título formal).
// - "AST" es el símbolo del token (como "ETH" para Ethereum).
// - `profesor.account.address` es la dirección del profesor, que probablemente será el dueño o el administrador del contrato.
  console.log(`Contrato deployado en ${contratoAsistencia.address}`);
  // Muestra por consola la dirección en la que quedó desplegado el contrato. Esta dirección es única en la blockchain y sirve para interactuar con ese contrato específico.

  //Verificar el Contrato
  await new Promise(resolve => setTimeout(resolve, 5000));
  // Pausa la ejecución del script durante 5 segundos (5000 milisegundos).
  // Esto se hace para esperar a que el contrato esté completamente registrado en el explorador de bloques antes de intentar verificarlo.
  try {
    await hre.run("verify:verify", {
      address: contratoAsistencia.address,
      constructorArguments: ["AsistenciaToken","AST",profesor.account.address],
    });
    // Intenta verificar el contrato en un explorador como Etherscan (si estás conectado a una red pública).
// Le pasa:
// - `address`: la dirección donde fue desplegado el contrato.
// - `constructorArguments`: los mismos argumentos usados al desplegarlo, necesarios para que Etherscan pueda compilar y confirmar el contrato.

    console.log("Contrato Verificado");
      // Muestra un mensaje indicando que la verificación fue exitosa.

  } catch (error) {
    console.log("Error verificando contrato:", error);
      // Si ocurre un error durante la verificación (por ejemplo, si ya está verificado o hubo un problema de red), muestra el error en consola.
  }

  //Insertar los addresses de los alumnos
  const tx1 = await contratoAsistencia.write.registrarAlumno([alumno1], {
    account: profesor.account.address
      });
      // Llama a la función `registrarAlumno` del contrato para registrar al alumno1.
// Usa la cuenta del profesor como firmante (es quien tiene permiso para hacer el registro).
// Devuelve una transacción (`tx1`) que contiene el hash y otros datos.

  const receipt1 = await publicClient.waitForTransactionReceipt({ hash: tx1 });
// Espera a que la transacción `tx1` se confirme en la blockchain (es decir, que sea minada).
// Guarda el recibo (`receipt1`), que contiene el resultado de la transacción (éxito, gas usado, logs, etc.).

  const tx2 = await contratoAsistencia.write.registrarAlumno([alumno2], {
    account: profesor.account.address
  });
  // Igual que antes, pero ahora registra al alumno2 con la cuenta del profesor.

  const receipt2 = await publicClient.waitForTransactionReceipt({ hash: tx2 });
// Espera la confirmación de la segunda transacción y guarda el resultado.

  console.log(`Alumno 1 registrado: ${receipt1.status === 'success' ? 'OK' : 'Failed'}`);
  // Muestra si el registro del alumno1 fue exitoso. Si `status` es 'success', imprime "OK"; si no, "Failed".
  console.log(`Alumno 2 registrado: ${receipt2.status === 'success' ? 'OK' : 'Failed'}`);
  // Hace lo mismo para el alumno2, informando si fue registrado correctamente.

  //Insertar primera sesión
  const hashPalabra = keccak256(stringToBytes(palabraSecreta));
  // Convierte la palabra secreta ("solidity") a bytes y luego calcula su hash con keccak256.
// Esto se hace para no guardar la palabra en texto plano en el contrato, aumentando la seguridad.

  const tx = await contratoAsistencia.write.crearSesion([hashPalabra, BigInt(duracionSesion)], {
    account: profesor.account.address
  });
  // Llama a la función `crearSesion` del contrato, pasando dos parámetros:
// - `hashPalabra`: el hash de la palabra secreta que los alumnos deberán conocer para marcar asistencia.
// - `BigInt(duracionSesion)`: convierte la duración (por ejemplo, 3) en tipo `BigInt`, como lo requiere Solidity.
// La transacción es firmada por el profesor.

  const receipt = await publicClient.waitForTransactionReceipt({ hash: tx });
  // Espera a que se confirme la transacción de creación de la sesión y guarda el resultado (receipt).

  console.log(`Sesión creada: ${receipt.status === 'success' ? 'OK' : 'Failed'}`);
// Muestra si la sesión fue creada con éxito. Si la transacción fue exitosa, imprime "OK"; si no, "Failed".

}

main().catch((err) => {
  // Llama a la función `main()` y, si ocurre algún error durante su ejecución, entra en el bloque `catch`.
  // El bloque `catch` captura cualquier excepción o error que ocurra en la ejecución de la función asíncrona `main()`.
  console.error(err);
   // Imprime el error en la consola para que puedas ver qué salió mal. `err` contiene el detalle del error ocurrido.

  process.exitCode = 1;
  // Establece el código de salida del proceso a 1, lo cual indica que el proceso terminó con un error.
  // Si no se establece, el valor por defecto es 0, lo que significa que el proceso terminó correctamente.
});
