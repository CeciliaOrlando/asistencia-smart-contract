// SPDX-License-Identifier: MIT       Licencia del contrato - MIT una de las mas abiertas y usadas
pragma solidity ^0.8.20;  // Compilador de Solidity

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol"; // Importa la definición del contrato ERC20 desde la librería OpenZeppelin. Voy a poder crear un token (como si fuera una moneda digital) sin tener que programarlo desde cero. Puedo Crear tokens, Transferirlos, Consultar saldos,etc.
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol"; // Importa la definición del contrato AccessControl desde la librería OpenZeppelin que permite manejar roles y permisos. Permite que el "profesor" pueda hacer algunas cosas y los "alumnos" otras.
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol"; // Importa la definición del contrato ReentrancyGuard desde la librería OpenZeppelin que permite evitar el reentrancy. que es como si alguien intentara "aprovechar un error" y ejecutar varias veces una función antes de que termine la anterior. Con ReentrancyGuard, te asegurás de que las funciones importantes se ejecuten una sola vez por turno, como deberían.

contract Asistencia is ERC20, AccessControl, ReentrancyGuard { //con el is se heredan las caracteristicas de los contratos ERC20, AccessControl y ReentrancyGuard

    bytes32 public constant PROFE_ROLE = keccak256("PROFE_ROLE"); // bytes32 Este es el tipo de dato. Significa que la variable va a guardar un valor de 32 bytes (256 bits). public Es un modificador de visibilidad. Significa que esta variable puede ser leída desde fuera del contrato (por otras funciones o por usuarios desde interfaces como Remix o Web3). constant Esto indica que el valor de esta variable es constante, es decir, no va a cambiar nunca después de ser definida. Se fija en el momento del despliegue del contrato. Ahorra gas porque no necesita guardarse en almacenamiento (solo en el bytecode). PROFE_ROLE Este es el nombre de la variable. Por convención, los nombres de constantes en Solidity se escriben en mayúsculas y con guiones bajos.  keccak256("PROFE_ROLE") Esto es una función hash que genera un valor único de 32 bytes a partir del string "PROFE_ROLE". keccak256(...) es la función de hash criptográfica estándar en Solidity (similar a SHA3). "PROFE_ROLE" es un string literal que se va a hashear. ¿Por qué se usa? En contratos de control de acceso (como con OpenZeppelin), se utiliza este hash como un identificador único para un rol. Por ejemplo, para saber si alguien tiene el rol de "PROFE".

    struct Session {  // Estructura para representar una sesión. Un struct es como un molde para crear "objetos" con varias propiedades
        bytes32 hash; // bytes32 Este es el tipo de dato. Significa que la variable va a guardar un valor de 32 bytes (256 bits).
        uint256 deadline; // unit256 Este es el tipo de dato. Significa que la variable va a guardar un valor de 256 bits. deadline La fecha límite para reclamar tokens, probablemente como una marca de tiempo Unix (block.timestamp), después de la cual la sesión ya no es válida.
        bool activa; // bool tipo de dato que significa que la variable va a guardar un valor booleano (true o false).Indica si la sesión está activa o no.
    }

    mapping(uint256 => Session) public sesiones; // mapping(address => bool) public alumnosPermitidosEste es un diccionario que relaciona un número (el ID de la sesión) con una estructura Session. Sirve para guardar todas las sesiones, y se puede acceder a cada una usando su ID (por ejemplo, 1, 2, 3...). Ejemplo: sesiones[1] te devuelve los datos de la sesión con ID 1. Como es public, se puede consultar directamente desde fuera del contrato.;
    mapping(address => bool) public alumnosPermitidos; //  Un mapping en Solidity es como un diccionario o una tabla de búsqueda. Sirve para asociar una clave con un valor. En este caso, se está creando una estructura que relaciona una dirección (address) con un valor booleano (bool). (address => bool) address: es la clave. Representa una dirección de Ethereum (como la de un usuario o un contrato). =>: indica que se va a mapear (asociar) una clave con un valor. bool: es el valor. Representa un valor booleano (verdadero o falso, o en código: true o false). Esto hace que la variable alumnosPermitidos sea pública, lo que significa que cualquiera puede consultar su contenido desde fuera del contrato. Solidity genera automáticamente una función de lectura para mappings públicos
    uint256 private sessionCounter; // Relaciona una dirección Ethereum (wallet) con un booleano. Indica si una dirección está permitida o no para participar en las sesiones (por ejemplo, si es un alumno autorizado). Ejemplo: alumnosPermitidos[0xABC...] == true significa que esa dirección está habilitada.
    mapping(uint256 => mapping(address => bool)) public haReclamado; // La declaración mapping(uint256 => mapping(address => bool)) public haReclamado; define un mapping en Solidity que tiene una estructura de diccionario anidado. En primer lugar, el primer mapping mapea un valor de tipo uint256 (números enteros sin signo, como identificadores o índices) a otro mapping. Este segundo mapping mapea una dirección (address) a un valor booleano (bool). Esto indica que para cada valor de tipo uint256, se tiene un sub-diccionario donde las claves son direcciones (address) y los valores son booleanos que indican si una determinada dirección ha realizado alguna acción, como reclamar un beneficio o acceder a una función. Al ser público, Solidity genera automáticamente una función de lectura que permite consultar si una dirección en particular ya ha reclamado algo para un identificador específico (por ejemplo, verificar si un usuario ha reclamado un premio para una campaña).

    event AlumnoRegistrado(address indexed alumno);
    event SessionCreada(uint256 indexed sessionId, bytes32 hash, uint256 deadline);
    event TokenReclamado(address indexed estudiante, uint256 cantidad, uint256 sessionId);
    constructor(
        string memory nombre,
        string memory simbolo,
        address professor
    ) ERC20(nombre, simbolo){
        require(professor != address(0));
        _grantRole(PROFE_ROLE, professor);

    }

    /**
     * @dev Permite al profesor registrar a un alumno.
     * @param _alumno Dirección del alumno a registrar.
     */
    function registrarAlumno(address _alumno) public onlyRole(PROFE_ROLE) {
        require(_alumno != address(0), "Direccion invalida");
        require(!alumnosPermitidos[_alumno], "Alumno ya registrado");

        alumnosPermitidos[_alumno] = true;

        emit AlumnoRegistrado(_alumno);
    }

    /**
     * @dev Permite al profesor crear una nueva sesión estableciendo un hash y una duración en días.
     * @param _hash El hash que representa la palabra secreta para la sesión.
     * @param _duracionEnDias Duración en días para la ventana de reclamación.
     */
    function crearSesion(bytes32 _hash, uint256 _duracionEnDias) public onlyRole(PROFE_ROLE) {
        require(_duracionEnDias > 0, "Duracion debe ser mayor que cero");

        uint256 deadline = block.timestamp + (_duracionEnDias * 1 days);

        uint256 sessionId = sessionCounter + 1;
        sessionCounter = sessionId;

        sesiones[sessionId] = Session({
             hash: _hash,
             deadline: deadline,
             activa: true
         });

        emit SessionCreada(sessionId, _hash, deadline);
    }

    /**
     * @dev Función para obtener detalles de una sesión específica.
     * @param _sessionId ID de la sesión a consultar.
     * @return hash El hash de la sesión.
     * @return deadline La fecha límite para reclamar tokens.
     * @return activa El estado de la sesión.
     */
     function obtenerSesion(uint256 _sessionId) public view returns (bytes32 hash, uint256 deadline, bool activa) {
         require(_sessionId > 0 && _sessionId <= sessionCounter, "Session ID invalido");
         Session memory sesion = sesiones[_sessionId];
         return (sesion.hash, sesion.deadline, sesion.activa);
     }

     /**
      * @dev Permite a un alumno registrado reclamar tokens proporcionando la palabra secreta para una sesión específica.
      * @param _sessionId ID de la sesión para la cual se reclama tokens.
      * @param _palabra La palabra secreta a ser hasheada y verificada.
      */
      function reclamarTokens(uint256 _sessionId, string memory _palabra) public nonReentrant {
          // Checks: Verificaciones
          require(alumnosPermitidos[msg.sender], "No estas autorizado para reclamar tokens");
          require(_sessionId > 0 && _sessionId <= sessionCounter, "Session ID invalido");
          Session memory sesion = sesiones[_sessionId];

          require(sesion.activa, "La sesion no esta activa");
          require(block.timestamp <= sesion.deadline, "La ventana de reclamacion ha cerrado");
          require(!haReclamado[_sessionId][msg.sender], "Ya has reclamado tokens para esta sesion");

          bytes32 hashCalculado = keccak256(abi.encodePacked(_palabra));

          require(hashCalculado == sesion.hash, "Palabra secreta incorrecta");

          // Effects: Actualizar el estado
          haReclamado[_sessionId][msg.sender] = true;


          // Interactions: Realizar interacciones externas o emitir tokens
          uint256 cantidad = 10 * (10 ** decimals());
          _mint(msg.sender, cantidad);

          emit TokenReclamado(msg.sender, cantidad, _sessionId);
      }


}
