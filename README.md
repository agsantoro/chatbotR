# Cómo integrar un chatbot de Gemini en una Shiny app

## Introducción

Geimini es el bot conversacional de Google basado en inteligencia artificial con el que se puede interactuar en la web en la web de [Gemini](https://gemini.google.com/) o a través de una API (interfaz de programación de aplicaciones). 

El uso de Gemini a través de la API permite integrarlo en aplicaciones. Si bien el uso de este servicio tiene costo, Google ofrece la posibilidad de probar su funcionamiento de manera limitada pero gratuita. Se puede obtener una api-key (una clave que permite utilizar la API de Gemini) ingresando aquí: (https://aistudio.google.com/).

Shiny es una librería del software estadístico R que permite desarrollar visualizaciones interactivas de datos con un lenguaje de programación sencillo. Esta librería permite sacar provecho de la versatilidad y simplicidad de R para el análisis de datos dentro de aplicaciones interactivas. 

En este artículo vamos a mostrar una forma de utilizar Gemini desde R para generar un chatbot dentro de una aplicación Shiny. Construiremos paso a paso una aplicación que integre un chatbot basado en Gemini al que se puedan efectuar consultas sobre un dataset, a través de la interfaz de usuario de una Shiny App.

## 1. Almacenamiento de la api-key de forma segura

Como primer paso, debemos guardar la clave que nos proveyó Google de manera segura, ya que al compartir el código de nuestra app a través de un repositorio, o al desplegarla en la web, podría quedar expuesta. Esto se hace creando un archivo que llamaremos ".Renviron" dentro del directorio raíz de nuestra aplicación de Shiny. Allí volcaremos la información para que quede resguardada. El contenido del archivo debe ser el siguiente:

```
GEMINI_API = [INSERTAR TU API-KEY ACÁ]
```
Si estás trabajando con GitHub, es necesario que agregues el archivo ".Renviron" a ".gitignore" de manera que no quede expuesta tu clave en el repositorio.

## 2. Librerías a utilizar

En este ejemplo vamos a utilizar tres librerías de R:

- shiny: para hacer una visualización interactiva a través de código en R

- glue: para crear dinámicamente cadenas de texto, lo que facilitará crear nombres prompts y nombres para asignar a inputs y outputs

- gemini.R: para interactuar con Gemini a través de la API desde un entorno R

- shinyjs: para ocultar e inhabilitar inputs para controlar la dinámica de la aplicación

Para utilizarlas debemos cargarlas y, debido a que vamos a usar gemini.R también debemos incluir la carga de la API key al comienzo de nuestra aplicación. De esta manera, nuestro script comenzará así:

```
library(shiny)
library(glue)
library(gemini.R)
library(shinyjs)

setAPI(Sys.getenv("GEMINI_API"))
```

Con la función setAPI de gemini.R indicamos la api-key que se usará para las consultas. Esta clave, como vimos, está almacenada en .Renviron y será leída desde ahí automáticamente.

## 3. Interfaz de usuario

Vamos a trabajar con una interfaz de usuario muy sencilla. Incluiremos un contenedor principal llamado "iaDiv" con los siguientes elementos:

- un comando que nos permitirá usar la librería shinyjs dentro de la app

- un uiOutput donde incluiremos la presentación del chat

- un contenedor vacío que llamaremos "chatBox" donde iremos volcando las respuestas del chat y las ventanas para agregar nuevas interacciones

- un botón para enviar los mensajes que, al comenzar la aplicación, aparecerá oculto

```
ui <- fluidPage(
  useShinyjs(), # permite usar la librería en la app
  h1("Gemini chat en Shiny"), # título de la app
  
  # contenedor
  div(id = "iaDiv",
      uiOutput("chatBox0"), # output para visualizar la presentación del chat
      div(id = "chatBox"), # contenedor vacío para mostrar las consultas y respuestas del chat
      hidden(actionButton("send", "Enviar mensaje")) # botón para enviar mensajes
  )
)

```


## 4. Server

Esta es la parte más compleja del código. Vamos a describirla por partes. 

### Chat 0

En primer lugar, crearemos dos valores reactivos para ir almacenando información que va a facilitar programar la dinámica de preguntas y respuestas del chat, y almacenar la historia para dar contexto a las respuestas. Las dos funciones reactivas que nos permitirán hacer esto se llamarán "chatNumber()" (inicializada en cero) y chatHistory (inicializada como un objeto vacío)

```
chatNumber = reactiveVal(0) # almacena el número de consulta/respuesta
chatHistory = reactiveValues() # almacena el historial de consultas y respuestas
```

Una vez que contamos con los valores reactivos, crearemos nuestro primer output. Lo llamaremos "chatBox0" ya que su función será mostrar el mensaje inicial que dará Gemini al usuario de la aplicación. Recordemos que nuestro chat servirá para entablar una conversación sobre un set de datos, donde Gemini colaborará en el análisis. 

El output lo crearemos usando la función renderUI() que nos va a permitir crear dinámicamente un contenedor HTML, que se mostrará dentro del contenedor vacío que creamos en la interfaz de usuario ("chatBox").

Gracias a este output, cada vez que se inicie la aplicación un mensaje que nosotros determinemos será enviado a Gemini, quién devolverá la primera respuesta de la conversación. Este output mostrará ese primer mensaje y un espacio vacío para que el usuario ingrese su nueva consulta.

Veamos los componentes de este output:

1. Un objeto que llamaremos "csv_output" con el dataset que le enviaremos a Gemini para que analice. En este caso, trabajaremos con Iris y lo guardaremos con este objeto como conjunto de valores separados por comas.

```
csvOutput <- capture.output(write.csv(iris, file = "", row.names = FALSE, quote = TRUE))
```

2.  Un objeto llamado dataPrompt para convertir el conjunto de valores separados por comas en una única cadena de texto grande, donde cada fila del dataset original se separa por un salto de línea.

```
dataPrompt = paste(csvOutput, collapse = "\n")
```

3. Un objeto llamado prompt donde insertaremos los datos de Iris en nuestro primer mensaje, con el que iniciaremos la conversación. Para este ejemplo, el mensaje será el siguiente: 

> A partir de ahora vas a interactuar con un usuario sobre la información estadística del dataset Iris, debes recibirlo con un mensaje de bienvenida. Aquí los datos en csv --->

Finalmente obtendremos el prompt completo insertándole los datos usando la función glue:

```
prompt = glue("A partir de ahora vas a interactuar con un usuario sobre la información estadística del dataset Iris, debes recibirlo con un mensaje de bienvenida. Aquí los datos en csv --->  {dataPrompt}")
```

A partir de ese prompt, generaremos un objeto nuevo con la respuesta (response). Debe tenerse en cuenta que el objeto que devuelve gemini.R es una lista donde ubica en la variable $history archiva el historial del chat. Este historial lo guardaremos en nuestro objeto reactivo chatHistory:

```
response = gemini_chat(prompt) # respuesta de Gemini   
chatHistory$history = response$history # almacenamiento del historial
```

Finalmente, mostraremos el botón send, ya que a partir de que la aplicación muestra la primera respuesta de Gemini, el usuario estará habilitado a enviar nuevos prompts. También, generaremos la "caja" HTML que se mostrará en el output "chat0" y un espacio para que el usuario ingrese un nuevo prompt:

```
shinyjs::show("send") # muestra el botón para enviar prompts

tagList(
  fluidRow(
    column(
      6,
      HTML(markdown::markdownToHTML(text = as.character(response$outputs), fragment.only = TRUE)), # muestra respuesta de Gemini
      textAreaInput("prompt0","Ingresar consulta") # abre área de texto para que el usuario ingrese un nuevo promtp
    )
  )
)
```

Podemos repasar ahora el output "chat0" completo:

```
output$chatBox0 = renderUI({
  
  # convierte el dataset a formato de texto para enviar junto al prompt
  csv_output <- capture.output(write.csv(iris, file = "", row.names = FALSE, quote = TRUE)) # guarda Iris como csv
  dataPrompt = paste(csv_output, collapse = "\n")
  
  # crea el promtp con los datos adjuntos
  prompt = glue("A partir de ahora vas a interactuar con un usuario sobre la información estadística del dataset Iris, debes recibirlo con un mensaje de bienvenida. Aquí los datos --->  {dataPrompt}")
  
  # obtiene respuesta de Gemini
  response = gemini_chat(prompt)
  
  # guarda el historial de chat
  chatHistory$history = response$history
  
  # muestra el botón para enviar prompts adicionales
  shinyjs::show("send")
  
  # crea el objeto que se mostrará en la interfaz de usuario
  tagList(
    fluidRow(
      column(
        6,
        HTML(markdown::markdownToHTML(text = as.character(response$outputs), fragment.only = TRUE)),
        textAreaInput("prompt0","Ingresar consulta")
      )
    )
  )
})
```

## Conversación con Gemini

Hasta aquí hemos realizado una primera consulta a Gemini le enviamos la instrucción original (que definimos en la variable "prompt"). Si hicimos todo bien, nuestra aplicación debería lucir similar a esto:

![alt text](https://github.com/agsantoro/chatbotR/blob/main/Images/1755090327217.png?raw=true)

Ahora debemos programar la dinámica de la conversación que va a entablar el usuario con Gemini a través de nuestra Shiny App. Para eso, vamos a definir un proceso que se va a iniciar cada vez que el usuario ingrese un mensaje y presione el botón "send" y que va a tener los siguientes componentes:

- Una variable que guarda el número de chat (value)

- Una variable que guarda el número de chat previo (prevValue)

- Un comando para insertar un contenedor en la interfaz de usuario (insertUI) que contenga la respuesta de Gemini a la consulta del usuario, el comando que agrega la nueva respuesta al historial de chat, un área para ingresar el texto de la próxima consulta (textAreaInput)

- Un comando para inhabilitar la edición de las consultas previas (disable)

- Un comando para diseñar el layout del bloque de UI que insertamos (tagList)

- Con estos componentes, el código queda de la siguiente manera:

observeEvent(input$send, {
    chatNumber(isolate(chatNumber()+1)) 
    value = isolate(chatNumber()) # almacena el número de chat
    prevValue = value-1 # almacena el número de chat previo

```
# inserta el nuevo contenedor en la UI
insertUI(
  selector = "#chatBox",
  where = "beforeEnd",
  ui = div(
    uiOutput(glue("chatBox{value}")))
)
    
output[[glue("chatBox{value}")]] = renderUI({
     
  output[[glue("gemini{value}")]] = renderUI({
        
    response = gemini_chat(input[[glue("prompt{prevValue}")]], isolate(chatHistory$history)) # respuesta de Gemini
     
    chatHistory$history = response$history # agrega nueva respuesta al historial
       
    HTML(markdown::markdownToHTML(text = as.character(response$outputs), fragment.only = TRUE)) # muestra respues con formato
   })
      
      output[[glue("prompt{value}")]] = renderUI({
        tagList(
          textAreaInput(glue("prompt{value}"),"Ingresar consulta") # agrega nueva área de texto
        )
      })
      
      shinyjs::disable(glue("prompt{prevValue}")) # inhabilita área de texto de conversación anterior
      
  # agrega bloque a la UI
  tagList(
    fluidRow(
      column(
        6,
        uiOutput(glue("gemini{value}")),
        uiOutput(glue("prompt{value}"))
            
      )
    )
  )
})
```

## 5. Conclusión

Se puede acceder al código completo aquí:

Trabajamos sobre la integración de un chatbot basado en Gemini en una visualización de datos. El uso de R, Shiny y Gemini en forma conjunta puede transformar la interacción de los usuarios de nuestras visualizaciones con los datos. Al integrar estas herramientas, se permite a los usuarios hacer preguntas en lenguaje natural, lo que elimina la necesidad de navegar por menúes, selectores o aplicar filtros. 

Con el modelo de aplicación presentada como base, puede cambiarse el origen de la información con un esfuerzo mínimo, con el objetivo de desarrollar una Shiny App donde el modelo generativo interprete datos propios (y no dataset de ejemplos como en este caso).

Dentro de las ventajas del desarrollo de este tipo de aplicaciones podemos destacar que, para quien tiene experiencia en R y Shiny, la integración es natural, aprovechando el mismo entorno de desarrollo para el análisis y la visualización. Esto permite una personalización completa de la interfaz y un control total sobre cómo el chatbot interactúa con los datos. Por otro lado, el entorno de desarrollo permite el aprovechamiento de las potencialidades de R para el análisis de datos. Además, las aplicaciones basadas en Shiny son fácilmente desplegables en la web a partir de los servicios de shinyapps.io 

Como limitación debe destacarse que en entornos R/Shiny, a pesar de poder manejar un número considerable de usuarios, la escalabilidad de la aplicación dependerá no solo del rendimiento de la aplicación en el servidor, sino también de la capacidad de la API de Gemini para gestionar el volumen de solicitudes, generando la necesidad de acceder a servicios pagos para aumentar la escala del producto.

Esperamos que haya sido de utilidad y puedan compartir sus experiencias en los comentarios.

Se puede acceder al código completo [aquí](https://github.com/agsantoro/chatbotR/blob/main/app.R)

