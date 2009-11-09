

$(function(){

  /* Contract sections */
  $('.contract_title').click(
    function(){
     $(this).toggleClass('open');
     $(this).find('.contract_short').toggle();
     id = $(this).find('.contract_short').attr('id');

     $("#" + id.replace(/_short/,'_long')).toggle();
    });
  
  
 


  /* Literature */
  $('div#literature > a').click(
    function(){
      $.ajax({url: $(this).attr('href'), success: function(){window.location.reload();}});
      return(false);
    });
  if ($('div#literature').length > 0){
    $('a.literature').click(
     function(){
       alert('No literature rankings available. Use the link at the top of the page and wait for results to be computed.');
       return(false);
     });
  }
  $('div#literature > span.processing').everyTime('60s', 'controlled', 
   function() { 
     $.ajax({
       url : '/ajax/done_literature?name=' + job,
       success: function(html){ 
         if (html == 'true'){ 
           $(this).stopTime('controlled');
           $(this).remove();
           window.location.reload(); 
         } 
       }
     })
   })

  /* Search */
  $('a.search').click(
    function(){
      url =  $(this).attr('href') 
      if ($('input.search').val().match(/\w/))
        url = url + '?words=' +  encodeURIComponent($('input.search').val());
      window.location = url;
      return(false);
  });

  /* Refactor */

  $('a.refactor').click(
    function(){
      url =  $(this).attr('href').replace(/=k/,"=" + $('input.refactor').val());
      
      $.ajax({url: url, success: function(){window.location.reload();}});
      return(false);
  });

  /* Table sort */

  $('table#literature').tablesorter({
    textExtraction : function(node) { 
      if (node.innerHTML.match('pubmed')){
        return ($(node).find('a').html());
      }else{
        return node.innerHTML;
      }
     }} );
  $('table#genecodis').tablesorter();

  /* Clear textareas */

  $('textarea').after('<a class="clear textarea_link" href="#">[clear]</a>');
  $('a.clear').click(
    function(){
      $(this).prev().attr('value','')
      $('textarea#ids').change();   

      return(false);
    })


  /* SENT ID's */
  if ($('textarea#output_genes').length > 0){
      $('input#submit').before('<p><a id="sent_ids" class="textarea_link" href="#">[SENT IDs]</a></p>');
      $('a#sent_ids').click(
        function(){
          genes = $('textarea#output_genes').attr('value');
          org   = $('select#dataset').val();

          window.navigator.sent_org   = org;
          window.navigator.sent_genes = genes;
          window.location='/';

          return(false);
          })
  }

  /* Tips */
  $('div.tooltip').hide();
  $('.tip').append("<a class='tip_anchor help' href='#'>[?]</a>");
  $('a.tip_anchor').hover(
    function(e){
      elem = $(this).parent().attr('id').replace('tip_anchor_', 'div#tip_');
      width = 500;

      $(elem).css('width', width).css('position','absolute');
      height = $(elem).height();

      pos_left =  $(this).position().left +  $(this).width() + 2 ;
      pos_top = $(this).position().top + $(this).height() + 2 ;

      diff = $(window).height() + $(window).scrollTop() - (pos_top + height + 50);
      if (diff < 0){
        pos_top = pos_top + diff;
      }

      $(elem).addClass('tooltip').show().
        css('left', pos_left + 'px').
        css('top', pos_top + 'px');
    },
    function(e){
      elem = $(this).parent().attr('id').replace('tip_anchor_', 'div#tip_');
      $(elem).hide();
  }).filter('a.help').click(function(){})


})
