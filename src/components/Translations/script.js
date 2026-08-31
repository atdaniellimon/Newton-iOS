var translation = null;

(async function(){
    let lang = navigator.language || 'en-US';
    lang     = lang.split('-')[0];

    async function fetchLangauge(which){
        const request = new Request(`/src/assets/langs/${which}.json`);
        const response = await fetch(request);
        
        if(!response.ok){
            return fetchLangauge('en');
        }
        
        return response.json();
    }

    translation = await fetchLangauge(lang);
    
    Moke.Hydration.register(translation);
    Moke.hydrateNode(document.body);
})();