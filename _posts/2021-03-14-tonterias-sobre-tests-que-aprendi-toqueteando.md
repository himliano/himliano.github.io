---
layout: post
title: Tonterías que sobre tests que aprendí toqueteando (I)
category: php
disqus: true
cover: https://images.daznservices.com/di/library/sporting_news/8d/48/larry-bird-ftr-061217jpg_105u8i4a3lel41hgegh11i6qy3.jpg?t=-1669912500&quality=100
---

Uno de mis últimos propósitos es intentar aprender a usar Symfony e intentar mejorar mis dotes como programador PHP. Y uno de los puntos donde más flaqueo, es en la parte de testing. Así que en mis ratos libres, pues estoy siempre con algún que otro invento tonto en PHP, donde voy probando a hacer algo y escribir un test. El progreso es lento, pero algo voy aprendiendo.

Hace unas semanas, me topé con un obstáculo un tanto tonto: ¿cómo probar fácilmente algo que involucra números aleatorios?

Veamos un ejemplo.

Supongamos que estamos programando una clase que simule el lanzamiento de un tiro de tres (un triple) en un partido de baloncesto. Como no queremos complicarnos mucho, vamos a asumir que tenemos una clase básica que representa a nuestro tirador:

```
<?php

class Player
{
    private int $threePointerScoring = 1;

    public function __construct(int $threePointerScoring)
    {
        $this->threePointerScoring = $threePointerScoring;
    }

    public function threePointShotGoesIn(): bool
    {
        return random_int(1, 100) < $this->threePointerScoring;
    }
}
```

Todo muy simple, una clase que al instanciarla le pasamos el porcentaje de acierto del jugador, y un método que, meadiante el úso de números al azar, nos sirve para determinar si el triple entra o no.

A primera vista, el test es muy sencillo. Nos encomendamos a un tirador que ronde el 40% y escribimos un test muy sencillo.

```
<?php

use PHPUnit\Framework\TestCase;

class TestPlayer extends TestCase
{
    public function testThreePointShotGoesIn(): void
    {
        $player = new Player(40);
        
        $goesIn = $player->threePointShotGoesIn()();
        
        self::assertTrue($goesIn);
    }
}
```

Instanciamos a nuestro tirador, lanzamos el triple y comprobamos que entra. Fácil, ¿no?

Pues aquí es donde vemos que empiezan los problemas, estamos sacando numeros al azar, no tenemos forma de saber de antemano cual va a salir. A veces lanzarás el test y dirá que todo ok, y otras veces el test fallará. Obviamente, así no vamos bien.

Ah, ya sé, hago un bucle en un test y lo ejecuto 100 veces, como el porcentaje es 40, debería salirme alrededor de 40 veces que el triple entra, ¿no? Pero... espera, son numeros al hacer, a lo mejor me sale solo 20 veces de cada 100 un numero que me interesa... o 41 de cada 100... mmm, mejor lo ejecuto cien mil veces, para estar seguro... o mejor un millón veces... o mejor....

**¡HEY! ¡ALTO!** ¿No ves que así no vamos bien? Éste es el tipo de ideas peregrinas de las que tenemos que escapar.

¿Dónde está el problema? Pues tenemos ahí incrustada la manera de generar los números aleatorios y éso nos limita bastante. ¿Cómo lo solucionamos? Pues vamos a sacar el problema de ahí y simplemente, que _otro_ se encargue de ese problema.

¿Qué tal si nos inventamos una clase que se encargue de generar esos números aleatorios y la empleamos en nuestra clase Player? Debería quedarnos algo así:

```
<?php

class RandomIntGenerator
{
    public function randomInt(int $min = 1, int $max = 100): int
    {
	return random_int(1, 100);
    }
}
```

El mismo comportamiento que teníamos antes, una clase con ún método que genera de la misma forma un número entero entre 1 y 100. Lo incluimos como dependencia de Player y lo empleamos.

```
<?php declare(strict_types=1);

use RandomIntGenerator;

class Player
{
    private int $threePointerScoring = 0;
    private RandomIntGenerator $randomIntGenerator;

    public function __construct(
        RandomIntGenerator $randomIntGenerator,
        int $threePointerScoring
    )
    {
        $this->threePointerScoring = $threePointerScoring;
        $this->randomIntGenerator = $randomIntGenerator;
    }

    public function threePointShot(): bool
    {
        return $this->randomIntGenerator->randomInt(1, 100) < $this->threePointerScoring;
    }
}
```

Ahora, el generar el número aleatorio es responsabilidad de otra clase, con lo que en nuestro test podemos tener ya al fin la posibilidad de controlar que número va a salir de ese generador al azar. ¿Cómo? Por ejemplo, a través de un mock.

```
<?php

use RandomIntGenerator;
use Player;
use PHPUnit\Framework\TestCase;

class TestPlayer extends TestCase
{
    public function testThreePointShotGoesIn(): void
    {
        $intGenerator = $this->createMock(RandomIntGenerator::class);
        $intGenerator->expects(self::once())
            ->method('randomInt')
            ->willReturn(20);
        $player = new Player($intGenerator, 40);

        $goesIn = $player->threePointShot();

        self::assertTrue($goesIn);
    }
}
```

Aquí lo que estamos haciendo es que cuando se ejecute el test, vamos a crear un mock de nuestro generador de números aleatorios. Y lo hemos configurado diciendo que a ese mock se le va a pedir una vez que ejecute su método **randomInt**, y que cuándo eso ocurra, va a devolver como resultado el número 20. Boom. Hemos pasado a controlar el azar.

Ahora ya disponemos de un test en el que el número al azar que saldrá será siempre el mismo, y un código para nuestra aplicación que realmente sacará siempre un número aleatorio. Ahora ya podemos ponernos a testear la clase con cuantos valores queramos, pero eliminando el problema de no controlar el valor que va a salir.

Pero, espera, ¿y si te pasa como a mí, que no tienes mucha práctica con éso de los mocks y no te sientes muy cómodo usando algo que no entiendes del todo? 

¿Probamos a resolverlo de otra forma? Vamos a probar a escribir una clase que podamos hacer pasar como un generador de números aleatorios, pero que en realidad devuelva un número que nosotros le digamos.

Vamos a escribir una interfaz que  podamos pasar como dependencia de Player, para poder intercambiar el generador de verdad con el de mentira según estemos en la app o en un test.

```
<?php

interface RandomIntInterface
{
    public function randomInt(int $min = 1, int $max = 100): int;
}
```

Una interfaz sencillita, que marca que la clase que la implementa, cumple nuestros requisitos sobre generar números aleatorios.

Nuestro generador apenas se ve modificado, porque ya funciona así.

```
<?php

namespace App\Generators;

use RandomIntInterface;

class RandomIntGenerator implements RandomIntInterface
{
    public function randomInt(int $min = 1, int $max = 100): int
    {
        return random_int($min, $max);
    }
}
```

Modificamos nuestra clase Player, y le decimos que ahora, en vez de recibir un RandomIntGenerator, lo que va a recibir es un objeto de una clase que implementa nuestra interfaz, por lo tanto, ese objeto, sea de la clase que sea, tendrá un método **randomInt** disponible.

```
<?php

use RandomIntGenerator;

class Player
{
    private int $threePointerScoring = 0;
    private RandomIntInterface $randomIntGenerator;

    public function __construct(
        RandomIntInterface $randomIntGenerator,
        int $threePointerScoring
    )
    {
        $this->threePointerScoring = $threePointerScoring;
        $this->randomIntGenerator = $randomIntGenerator;
    }

    public function threePointShot(): bool
    {
        return $this->randomIntGenerator->randomInt(1, 100) < $this->threePointerScoring;
    }
}
```

Esta clase, como vemos, tampoco cambia mucho.

¿Qué nos queda? Pues escribir nuestro falso generador de números aleatorios.

```
<?php

use RandomIntInterface;

class NonRandomIntGenerator implements RandomIntInterface
{
    public int $intToReturn = 0;

    public function randomInt(int $min = 1, int $max = 100): int
    {
        return $this->intToReturn;
    }
}
```

Una clase que cuando le pidamos un número aleatorio, devolverá el número contenido en una propiedad pública. Emplearlo en un test debería ser pan comido.

```
<?php

use NonRandomIntGenerator;
use PHPUnit\Framework\TestCase;

class TestPlayer extends TestCase
{
    public function testThreePointShotGoesIn(): void
    {
        $intGenerator = new NonRandomIntGenerator();
        $intGenerator->intToReturn = 20;
        
        $player = new Player($intGenerator, 40);

        $goesIn = $player->threePointShot();

        self::assertTrue($goesIn);
    }
}
```

Fácil, no?

Un saludo.