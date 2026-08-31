/**
 * Newton I - Hybrid Generative System (v3.0)
 * Detects intent and dynamically synthesizes a unique response using base templates.
 */

class NewtonI {
    constructor(config = {}){
        this.version = '3.0.0';
        this.name = 'Newton I (Generative)';
        
        this.config = {
            temperature: config.temperature || 0.6, // Higher temperature for more randomness
            ...config
        };
        
        this.isTrained = false;
        this.intents = new Map();
        this.fallbackResponses = {};
        
        // Dictionary for dynamic synonym replacement
        this.synonyms = {
            "help": ["assist", "support", "guide you", "lend a hand"],
            "hello": ["Greetings", "Hi there", "Hello", "System ready. Hi"],
            "question": ["inquiry", "query", "thought", "hypothesis"],
            "code": ["script", "algorithm", "source code", "logic"]
        };
    }
    
    async initialize(){
        console.log('🧠 Newton I - Initializing hybrid generative core...');
        return this;
    }
    
    loadTrainingData(trainingData){
        this.trainingData = trainingData;
        this._buildIntentClassifier();
        this.isTrained = true;
        console.log(`📚 Core mapped with ${trainingData.conversations.length} base knowledge templates`);
        return this;
    }
    
    _buildIntentClassifier(){
        for (const conv of this.trainingData.conversations){
            const userMsg = conv.user.toLowerCase();
            const response = conv.newton;
            const keywords = this._extractKeywords(userMsg);
            
            const intentId = `intent_${this.intents.size}`;
            this.intents.set(intentId, {
                keywords: keywords,
                baseTemplate: response,
                originalUser: userMsg
            });
        }
        
        this.fallbackResponses = {
            greeting: [
                "initiating greeting protocols. How can I help?",
                "ready for input. What's on your mind?",
                "systems online. Awaiting your query."
            ],
            question: [
                "fascinating domain. Could you expand on that?",
                "I need a few more parameters to calculate an answer.",
                "let's dive deeper. What specifically do you want to know?"
            ],
            code: [
                "compiling thoughts... what specific logic are we debugging?",
                "I can analyze that algorithm. Drop the code snippet.",
                "let's optimize. What framework or language are we targeting?"
            ],
            unknown: [
                "insufficient data for a precise output. Could you rephrase?",
                "I'm hitting a logical wall. Can you provide more context?"
            ]
        };
    }
    
    _extractKeywords(text){
        const stopwords = new Set([
            'the', 'a', 'an', 'and', 'or', 'but', 'so', 'for', 'of', 'to', 'in',
            'is', 'are', 'was', 'were', 'be', 'been', 'having', 'do', 'does', 'did',
            'i', 'you', 'he', 'she', 'it', 'we', 'they', 'my', 'your', 'what', 'when',
            'where', 'which', 'who', 'this', 'that', 'not', 'no', 'very', 'just', 'please'
        ]);
        
        const words = text.toLowerCase().replace(/[^a-z0-9\s]/g, '').split(/\s+/);
        return words.filter(w => w.length > 2 && !stopwords.has(w));
    }
    
    async generate(prompt, options = {}){
        const normalizedPrompt = prompt.toLowerCase().trim();
        const matchedIntent = this._detectIntent(normalizedPrompt);
        
        let baseResponse = "";
        
        // Lowered confidence threshold to catch more natural language
        if (matchedIntent && matchedIntent.confidence > 0.25){
            baseResponse = matchedIntent.baseTemplate;
        } else {
            const category = this._detectCategory(normalizedPrompt);
            const fallbacks = this.fallbackResponses[category] || this.fallbackResponses.unknown;
            baseResponse = fallbacks[Math.floor(Math.random() * fallbacks.length)];
        }
        
        // Pass the base template to the generative synthesizer
        return this._synthesizeResponse(baseResponse, normalizedPrompt);
    }
    
    _synthesizeResponse(base, userPrompt){
        // 1. Dynamic Intros & Outros (Contextual wrappers)
        const intros = [
            "From my analysis, ",
            "Here is what I found: ",
            "Based on the parameters: ",
            "Let's break this down. ",
            "" // Sometimes no intro is best
        ];
        
        const outros = [
            " Does this align with your hypothesis?",
            " Let me know if you need to debug further.",
            " Should we explore another angle?",
            "" 
        ];

        let intro = intros[Math.floor(Math.random() * intros.length)];
        let outro = outros[Math.floor(Math.random() * outros.length)];

        // Don't add wrappers to pure code blocks
        if (base.includes('```')){
            intro = "Here is the implementation you requested:\n";
            outro = "\nLet me know if this compiles correctly.";
        }

        // 2. Simple synonym mutation (Pseudo-generation)
        let mutatedBase = base;
        if (Math.random() < this.config.temperature){
            for (const [key, replacements] of Object.entries(this.synonyms)){
                if (mutatedBase.toLowerCase().includes(key)){
                    const randomReplacement = replacements[Math.floor(Math.random() * replacements.length)];
                    const regex = new RegExp(`\\b${key}\\b`, "gi");
                    mutatedBase = mutatedBase.replace(regex, randomReplacement);
                }
            }
        }

        // 3. Assemble and clean up grammar
        let finalResponse = `${intro}${mutatedBase}${outro}`.trim();
        finalResponse = finalResponse.charAt(0).toUpperCase() + finalResponse.slice(1);
        
        return finalResponse;
    }
    
    _detectIntent(prompt){
        const promptKeywords = this._extractKeywords(prompt);
        if (promptKeywords.length === 0) return null;
        
        let bestIntent = null;
        let bestScore = 0;
        
        for (const [id, intent] of this.intents.entries()){
            let matches = 0;
            for (const kw of promptKeywords){
                if (intent.keywords.some(ik => ik.includes(kw) || kw.includes(ik))) matches++;
                if (intent.originalUser.includes(kw)) matches += 0.5;
            }
            
            let score = matches / Math.max(promptKeywords.length, 1);
            const exactMatches = intent.keywords.filter(ik => prompt.includes(ik)).length;
            score += exactMatches * 0.4; // Boosted weight for exact matches
            
            if (score > bestScore && score > 0.25){ // Lowered threshold
                bestScore = score;
                bestIntent = {
                    baseTemplate: intent.baseTemplate,
                    confidence: score,
                    id: id
                };
            }
        }
        
        return bestIntent;
    }
    
    _detectCategory(prompt){
        if (prompt.match(/^(hello|hi|hey|greetings|good)/)) return 'greeting';
        if (prompt.includes('code') || prompt.includes('function') || prompt.includes('```') || prompt.includes('error')) return 'code';
        if (prompt.includes('?') || prompt.match(/^(what|why|how|when|where|who)/)) return 'question';
        return 'unknown';
    }
    
    getStatus(){
        return {
            isTrained: this.isTrained,
            intentsLoaded: this.intents.size,
            config: this.config
        };
    }
}

// Global registration
if (typeof window !== 'undefined'){
    window.NewtonI = NewtonI;
    console.log('✅ NewtonI v3.0 ready (Generative Hybrid)');
}

if (typeof module !== 'undefined' && module.exports){
    module.exports = { NewtonI };
}
