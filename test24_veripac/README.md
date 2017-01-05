# veripac9
Este proyecto es el procesador interpretado del cartucho Videopac-9, implementado como un subprocesador del ZX Spectrum.

No se necesita ningún addon (dispositivo en el puerto de expansión del ZX-Uno), lo único necesario es cargar este core, y luego cargar el software VERIPAC9.tap que está [aquí](https://github.com/yomboprime/ZXYLib)




El bus externo se conecta a la memoria interna, donde se da preferencia al maestro de bus externo frente al uso interno.

A la vez, la ejecución de la soft-cpu está multiplexada en el tiempo con el uso de la señal step, de forma que el z80 puede detener la ejecución y proceder a leer o escribir.

Todos los registros están mapeados en el espacio de memoria interna:

MAPA DE MEMORIA

00 - C9: bytes de ram

CA: Control:
	En lectura da el estado de la máquina:
	bits 1,0: estado de la UC:
		0: fetch
		1: fetch 2
		2: ejecución
		3: halt
	bit 2: buzzer (1 ó 0)
	
	En escritura:
	bit 0: Señal STEP
	bit 1: Señal RESET

CB: Registro para escribir las teclas pulsadas.
En lectura:
	bit 0: Indica a 1 que se está requiriendo una tecla.

CC: acumulador

CD: program counter

CE: registro de instruccion

CF: data counter

D0 - EF: Buffer de pantalla 32 bytes (2 lineas 16 caracteres)

F0 - FF: 16 registros

---------

ADICIONES / MODIFICACIONES A LA MAQUINA

Front-end de spectrum que permite cargar programas desde SD y ejecutar paso a paso entre otras cosas.

202 bytes de ram en lugar de 100

números hexadecimales 0 a FF o sea de 0 a 255 decimal, en lugar de dos dígitos decimales.

Instrucciones nuevas: por determinar los opcodes no usados.
