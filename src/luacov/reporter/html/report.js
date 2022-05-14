function initialize() {
   const inputList = Array.prototype.slice.call(document.getElementsByTagName("h2"));
   inputList.forEach(function (item) {
      item.onclick = function () {
         if (item.parentElement.className.startsWith('hidden')) {
            item.parentElement.className = item.parentElement.className.replace('hidden ', '')
         } else {
            item.parentElement.className = 'hidden ' + item.parentElement.className
         }
      }
   });

   prettyPrint()
}
