makeTermsTable <- function(table, genesDelim,
                           datasetURL,
                           caption = NULL,
                           includeColumns = c('Term Description', 'Hits', 'p-Value (adj.)', 'p-Value', 'Genes in Term')) {

  if (nrow(table) != 0) {
    table$'Genes in Term' <- gsub(pattern = genesDelim, replacement = ',', x = table$'Genes in Term')
    table$'Genes in Term' <- multi_hyperlink_text(labels = table$'Genes in Term', links = "https://www.genecards.org/cgi-bin/carddisp.pl?gene=")

    if(!is.null(datasetURL)) {
      table$'Term Description' <- hyperlink_text(href_base = datasetURL, href_cont = table$'Term ID', link_text = table$'Term Description')
    }


    table <- table %>%
      dplyr::select(tidyselect::all_of(includeColumns)) %>%
      dplyr::arrange(`p-Value (adj.)`) %>%
      DT::datatable(
        caption = caption,
        filter = 'bottom',
        selection = 'single',
        escape = FALSE,
        autoHideNavigation = TRUE,
        rownames = FALSE,
        extensions = c('Buttons'),
        class = 'cell-border stripe',
        options = list(
          dom = 'lBfrtip',
          lengthMenu = list(c(15, 30, 50, 100, -1), c('15', '30', '50', '100', 'All')),
          pageLength = 10,
          scrollX = TRUE,
          buttons = list(
            'colvis',
            list(
              extend = 'collection',
              text = 'Download/Copy',
              buttons = c('copy', 'csv', 'excel')
            )
          )
        )
      ) # %>% formatStyle( 0, target= 'row',color = 'black', backgroundColor = NULL, fontWeight = NULL, lineHeight='50%')
  }
}

# TODO: download entire dataset:
# server = FALSE
renderPlotSet <- function(output, key, enrichTypeResult, datasetURL, datasetName = NULL, caption = NULL, namedGeneList = NULL) {
  output[[paste(key, 'table', sep = '_')]] <- DT::renderDataTable({
    er <- enrichTypeResult()
    validate(need(!is.null(er) & nrow(er) != 0, ''))
    table <- er %>% as.data.frame() %>%
      dplyr::rename(
        'Term Description' = Description,
        'Term ID' = ID,
        'geneID' = geneID,
        'Hits' = Count,
        'p-Value (adj.)' = pvalue,
        'p-Value' = p.adjust,
        'Genes in Term' = geneID
      )

    makeTermsTable(table = table, genesDelim = '/',
                   datasetURL = datasetURL,
                   caption = caption,
                   includeColumns = c('Term Description', 'Hits', 'p-Value (adj.)', 'p-Value', 'Genes in Term'))  })

  output[[paste(key, 'dotplot', sep = '_')]] <- plotly::renderPlotly({
    er <- enrichTypeResult()
    validate(need(!is.null(er) & nrow(er) != 0, 'No enriched terms.'))
    enrichplot::dotplot(er)
  })

  output[[paste(key, 'emapplot', sep = '_')]] <- renderPlot({
    er <- enrichTypeResult()
    validate(need(!is.null(er) & nrow(er) != 0, 'No enriched terms.'))
    toPlot <- enrichplot::pairwise_termsim(er)
    enrichplot::emapplot(toPlot)
  })

  output[[paste(key, 'cnetplot', sep = '_')]] <- renderPlot({
    er <- enrichTypeResult()
    validate(need(!is.null(er) & nrow(er) != 0, 'No enriched terms.'))
    enrichplot::cnetplot(er, categorySize="p-Value (adj.)", foldChange = namedGeneList, circular = TRUE, colorEdge = TRUE)
  })

  output[[paste(key, 'upsetplot', sep = '_')]] <- renderPlot({
    er <- enrichTypeResult()
    validate(need(!is.null(er) & nrow(er) != 0, 'No enriched terms.'))
    enrichplot::upsetplot(er)
  })

  output[[paste(key, 'heatplot', sep = '_')]] <- renderPlot({
    er <- enrichTypeResult()
    validate(need(!is.null(er) & nrow(er) != 0, 'No enriched terms.'))
    enrichplot::heatplot(er, foldChange = namedGeneList)
  })
}


makeTabBox <- function(title, key) {
  shinydashboard::tabBox(
    title = title,
    side = 'right',
    height = NULL,
    selected = 'Table',
    width = 16,
    tabPanel('Table', DT::dataTableOutput(paste(key, 'table', sep = '_'))),
    tabPanel('Dot Plot', plotly::plotlyOutput(paste(key, 'dotplot', sep = '_'))),
    tabPanel('Emap Plot', plotOutput(paste(key, 'emapplot', sep = '_'))),
    tabPanel('Cnet Plot', plotOutput(paste(key, 'cnetplot', sep = '_'))),
    tabPanel('Upset Plot', plotOutput(paste(key, 'upsetplot', sep = '_'))),
    tabPanel('Heat Plot', plotOutput(paste(key, 'heatplot', sep = '_')))
  )
}

#https://github.com/daattali/advanced-shiny/tree/master/busy-indicator
withBusyIndicatorCSS <- "
.btn-loading-container {
margin-left: 10px;
font-size: 1.2em;
}
.btn-done-indicator {
color: green;
}
.btn-err {
margin-top: 10px;
color: red;
}
"

withBusyIndicatorUI <- function(button) {
  id <- button[['attribs']][['id']]
  div(
    shinyjs::useShinyjs(),
    singleton(tags$head(
      tags$style(withBusyIndicatorCSS)
    )),
    `data-for-btn` = id,
    button,
    span(
      class = "btn-loading-container",
      shinyjs::hidden(
        icon("spinner", class = "btn-loading-indicator fa-spin"),
        icon("check", class = "btn-done-indicator")
      )
    ),
    shinyjs::hidden(
      div(class = "btn-err",
          div(icon("exclamation-circle"),
              tags$b("Error: "),
              span(class = "btn-err-msg")
          )
      )
    )
  )
}

withBusyIndicatorServer <- function(buttonId, expr) {
  loadingEl <- sprintf("[data-for-btn=%s] .btn-loading-indicator", buttonId)
  doneEl <- sprintf("[data-for-btn=%s] .btn-done-indicator", buttonId)
  errEl <- sprintf("[data-for-btn=%s] .btn-err", buttonId)
  shinyjs::disable(buttonId)
  shinyjs::show(selector = loadingEl)
  shinyjs::hide(selector = doneEl)
  shinyjs::hide(selector = errEl)
  on.exit({
    shinyjs::enable(buttonId)
    shinyjs::hide(selector = loadingEl)
  })

  tryCatch({
    value <- expr
    shinyjs::show(selector = doneEl)
    shinyjs::delay(2000, shinyjs::hide(selector = doneEl, anim = TRUE, animType = "fade",
                                       time = 0.5))
    value
  }, error = function(err) { errorFunc(err, buttonId) })
}

errorFunc <- function(err, buttonId) {
  errEl <- sprintf("[data-for-btn=%s] .btn-err", buttonId)
  errElMsg <- sprintf("[data-for-btn=%s] .btn-err-msg", buttonId)
  errMessage <- gsub("^ddpcr: (.*)", "\\1", err$message)
  shinyjs::html(html = errMessage, selector = errElMsg)
  shinyjs::show(selector = errEl, anim = TRUE, animType = "fade")
}
