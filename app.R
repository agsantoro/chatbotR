library(shiny)
library(glue)
library(gemini.R)
library(shinyjs)

setAPI(Sys.getenv("GEMINI_API"))

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

server <- function(input, output, session) {
  
  chatNumber = reactiveVal(0) # almacena el número de consulta/respuesta
  chatHistory = reactiveValues() # almacena el historial de consultas y respuestas
  
  output$chatBox0 = renderUI({
    
    csv_output <- capture.output(write.csv(iris, file = "", row.names = FALSE, quote = TRUE)) # guarda Iris como csv
    
    dataPrompt = paste(csv_output, collapse = "\n") # convierte el conjunto de valores separados por comas en una única cadena de texto
    
    prompt = glue("A partir de ahora vas a interactuar con un usuario sobre la información estadística del 
                  dataset Iris, debes recibirlo con un mensaje de bienvenida. Aquí los datos --->  
                  {dataPrompt}") # prompt completo con los datos
    
    response = gemini_chat(prompt) # respuesta de Gemini
    
    chatHistory$history = response$history # agrega la respuesta al historial de chat
    
    shinyjs::show("send") # muestra el botón send (oculto al inicio de la app)
    
    # diseño del layout de este bloque de UI
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
  
  observeEvent(input$send, {
    chatNumber(isolate(chatNumber()+1)) 
    value = isolate(chatNumber()) # almacena el número de chat
    prevValue = value-1 # almacena el número de chat previo
    
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
  })
  
  
}

shinyApp(ui, server)
