local GameModule = {}
--123213123
function GameModule.Register(api)
    api.AddCategory("Automation", "AUTOMATION", function(page)
        local TweenService = game:GetService("TweenService")

        local CARD = Color3.fromRGB(17, 23, 33)
        local PANEL = Color3.fromRGB(14, 19, 28)
        local TEXT = Color3.fromRGB(235, 242, 250)
        local MUTED = Color3.fromRGB(145, 160, 180)
        local WHITE = Color3.fromRGB(255, 255, 255)

        local completeWordsEnabled = false

        -- Common A1-level English words, plus a few X words for rare starting letters.
        local WORDS = {
            "a", "about", "above", "across", "act", "add", "address", "afraid", "after", "afternoon", "again", "age", "ago", "air", "airport", "all", "also", "always", "am", "an", "and", "angry", "animal", "answer", "any", "apple", "april", "arm", "around", "arrive", "art", "ask", "at", "aunt", "autumn", "away", "baby", "back", "bad", "bag", "ball", "banana", "band", "bank", "bath", "bathroom", "be", "beach", "beautiful", "because", "become", "bed", "bedroom", "beer", "before", "begin", "behind", "believe", "below", "best", "better", "between", "big", "bike", "bird", "birthday", "black", "blue", "boat", "body", "book", "boot", "bored", "boring", "born", "both", "bottle", "box", "boy", "bread", "breakfast", "brother", "brown", "build", "bus", "busy", "but", "buy", "by", "bye", "cake", "call", "camera", "can", "cannot", "car", "card", "care", "careful", "carry", "cat", "catch", "chair", "change", "cheap", "check", "cheese", "chicken", "child", "children", "chocolate", "choose", "cinema", "city", "class", "classroom", "clean", "clever", "climb", "clock", "close", "clothes", "cloud", "cloudy", "club", "coat", "coffee", "cold", "college", "color", "come", "computer", "concert", "cook", "cooking", "cool", "correct", "cost", "country", "course", "cousin", "cow", "cream", "cup", "customer", "cut", "dad", "dance", "dangerous", "dark", "date", "daughter", "day", "dear", "december", "decide", "delicious", "desk", "dictionary", "die", "diet", "dinner", "dirty", "do", "doctor", "dog", "door", "down", "draw", "dream", "dress", "drink", "drive", "driver", "during", "each", "ear", "early", "east", "easy", "eat", "egg", "eight", "eighteen", "eighty", "elephant", "eleven", "else", "email", "end", "enjoy", "enough", "euro", "evening", "ever", "every", "example", "excellent", "excuse", "exercise", "expensive", "explain", "extra", "eye", "face", "fact", "fall", "family", "famous", "fan", "fantastic", "far", "farm", "farmer", "fast", "fat", "father", "favorite", "february", "feel", "feeling", "festival", "few", "fifteen", "fifth", "fifty", "fill", "film", "find", "fine", "finish", "fire", "first", "fish", "five", "flat", "floor", "flower", "fly", "food", "foot", "football", "for", "forget", "form", "forty", "four", "fourteen", "fourth", "free", "friday", "friend", "friendly", "from", "front", "fruit", "full", "fun", "funny", "game", "garden", "geography", "get", "girl", "give", "glass", "go", "good", "goodbye", "grandfather", "grandmother", "grandparent", "great", "green", "grey", "ground", "group", "grow", "guess", "guitar", "gym", "hair", "half", "hand", "happen", "happy", "hard", "hat", "hate", "have", "he", "head", "headache", "health", "healthy", "hear", "heart", "heavy", "hello", "help", "her", "here", "hey", "hi", "high", "hill", "him", "his", "history", "hobby", "holiday", "home", "homework", "hope", "horse", "hospital", "hot", "hotel", "hour", "house", "how", "hundred", "hungry", "husband", "i", "ice", "idea", "if", "imagine", "important", "in", "information", "interest", "interesting", "internet", "into", "introduce", "island", "it", "its", "jacket", "january", "job", "join", "joke", "journey", "juice", "july", "jump", "june", "just", "keep", "key", "kid", "kind", "kitchen", "knife", "know", "language", "large", "last", "late", "later", "laugh", "learn", "leave", "left", "leg", "lesson", "letter", "library", "life", "light", "like", "line", "listen", "little", "live", "living", "room", "long", "look", "lose", "lot", "love", "low", "lunch", "machine", "magazine", "main", "make", "man", "manager", "many", "map", "march", "market", "married", "match", "may", "me", "meal", "mean", "meat", "meet", "member", "menu", "message", "middle", "midnight", "might", "milk", "million", "minute", "miss", "mistake", "monday", "money", "month", "moon", "more", "morning", "mother", "mountain", "mouse", "mouth", "move", "movie", "mr", "mrs", "much", "mum", "music", "must", "my", "name", "near", "need", "never", "new", "news", "next", "nice", "night", "nine", "nineteen", "ninety", "no", "noise", "north", "nose", "not", "notebook", "nothing", "november", "now", "number", "nurse", "october", "of", "off", "office", "often", "oh", "ok", "old", "on", "once", "one", "onion", "online", "only", "open", "or", "orange", "order", "other", "our", "out", "outside", "over", "own", "page", "paint", "pair", "paper", "parent", "park", "part", "party", "pass", "past", "pay", "pen", "pencil", "people", "pepper", "perfect", "person", "pet", "phone", "photo", "piano", "picture", "piece", "pig", "pink", "place", "plan", "plane", "plant", "play", "player", "please", "point", "police", "pool", "poor", "popular", "potato", "pound", "practice", "present", "pretty", "price", "problem", "product", "program", "project", "pull", "purple", "put", "question", "quick", "quiet", "quite", "radio", "rain", "read", "ready", "real", "really", "red", "remember", "repeat", "rest", "restaurant", "return", "rice", "right", "river", "road", "rose", "round", "rule", "run", "sad", "safe", "salad", "salt", "same", "sandwich", "saturday", "say", "school", "science", "sea", "second", "see", "sell", "send", "september", "seven", "seventeen", "seventy", "share", "she", "sheep", "shirt", "shoe", "shop", "shopping", "short", "should", "show", "sick", "sing", "sister", "sit", "six", "sixteen", "sixty", "skirt", "sleep", "slow", "small", "smile", "snow", "so", "sofa", "some", "something", "son", "song", "soon", "sorry", "sound", "south", "speak", "special", "spell", "spend", "sport", "spring", "stand", "start", "station", "stay", "stop", "story", "street", "strong", "student", "study", "subject", "success", "such", "sugar", "summer", "sunday", "sun", "super", "supermarket", "sure", "surprise", "sweet", "swimming", "table", "take", "talk", "tall", "tea", "teach", "teacher", "team", "teenager", "telephone", "television", "tell", "ten", "tennis", "terrible", "test", "than", "thank", "thanks", "that", "the", "their", "them", "then", "there", "these", "they", "thing", "think", "third", "thirteen", "thirty", "this", "those", "thousand", "three", "through", "thursday", "ticket", "tidy", "time", "tired", "to", "today", "together", "tomato", "tomorrow", "tonight", "too", "tooth", "top", "town", "traffic", "train", "travel", "tree", "trip", "trousers", "tuesday", "turn", "twelve", "twenty", "twice", "two", "type", "umbrella", "uncle", "under", "understand", "uniform", "until", "up", "us", "use", "useful", "usually", "vacation", "vegetable", "very", "video", "view", "visit", "voice", "wait", "walk", "wall", "want", "warm", "wash", "watch", "water", "way", "we", "wear", "weather", "website", "wednesday", "week", "weekend", "welcome", "well", "west", "what", "when", "where", "which", "white", "who", "why", "wife", "will", "win", "window", "windy", "winter", "with", "without", "woman", "wonderful", "word", "work", "worker", "world", "write", "writer", "wrong", "year", "yellow", "yes", "yesterday", "you", "young", "your", "zoo", "xray", "xylophone", "xenon", "xerox", "aardvark", "abacus", "abdomen", "abolish", "absorb", "abstract", "absurd", "academy", "accent", "accept", "access", "accident", "account", "ache", "acid", "acquire", "adapt", "addict", "admire", "adopt", "adult", "advance", "advice", "affect", "afford", "agency", "agenda", "aggressive", "ahead", "aid", "aim", "airless", "aisle", "alarm", "alcohol", "alert", "alien", "alike", "alive", "alley", "alphabet", "alter", "amateur", "amaze", "ambition", "amount", "anchor", "ancient", "ankle", "announce", "annual", "another", "ant", "antique", "anxiety", "anybody", "anyhow", "apart", "apology", "appear", "appetite", "applaud", "apply", "appoint", "approve", "arch", "area", "arena", "argue", "arise", "armor", "army", "arrange", "arrest", "arrow", "article", "artist", "artwork", "ash", "ashamed", "aside", "asleep", "aspect", "assist", "assume", "athlete", "atom", "attach", "attack", "attempt", "attend", "attitude", "attract", "audience", "author", "auto", "available", "average", "avoid", "awake", "award", "aware", "awful", "awkward", "axe", "axis", "aye", "azure", "babble", "bachelor", "bacon", "badge", "baggy", "bake", "balcony", "bald", "ballad", "bamboo", "ban", "banish", "banner", "bargain", "bark", "barrel", "barrier", "basic", "basin", "basis", "battery", "battle", "bay", "bean", "beard", "beast", "beat", "beauty", "bedrock", "bee", "beef", "beet", "beg", "behave", "belief", "bell", "belong", "belt", "bench", "bend", "benefit", "berry", "beside", "bicycle", "bid", "bill", "bind", "biology", "birth", "biscuit", "bite", "bitter", "blade", "blame", "blanket", "blast", "blaze", "bleed", "blend", "bless", "blind", "blink", "block", "bloom", "blossom", "blouse", "blow", "board", "boast", "boil", "bold", "bolt", "bomb", "bond", "bone", "bonus", "boom", "boost", "border", "bore", "borrow", "boss", "bother", "bounce", "boundary", "bow", "bowl", "brain", "branch", "brand", "brave", "brick", "bride", "bridge", "brief", "bright", "brilliant", "bring", "broad", "broken", "bronze", "broom", "brush", "bubble", "bucket", "budget", "buffalo", "bulb", "bulk", "bull", "bullet", "bundle", "burden", "burger", "burn", "burst", "bury", "bush", "business", "butter", "butterfly", "button", "buzz", "cab", "cabin", "cable", "cactus", "cafe", "cage", "calculate", "calendar", "calf", "calm", "camel", "camp", "campaign", "canal", "cancel", "cancer", "candidate", "candle", "candy", "cane", "cannon", "canoe", "canvas", "cap", "capable", "capital", "captain", "capture", "carbon", "career", "careless", "carpet", "cart", "case", "cash", "casino", "castle", "casual", "catalog", "category", "cattle", "cause", "cave", "ceiling", "celebrate", "cell", "celery", "cement", "century", "cereal", "ceremony", "certain", "chain", "chalk", "champion", "chance", "channel", "chapter", "character", "charge", "charm", "chase", "cheat", "cheek", "cheer", "chemical", "chest", "chief", "chimney", "chin", "chip", "choice", "church", "circle", "circuit", "circus", "citizen", "civil", "claim", "clap", "classic", "clear", "clerk", "click", "client", "cliff", "clinic", "clip", "clone", "cloth", "clown", "clue", "coach", "coal", "coast", "code", "coin", "collapse", "collar", "collect", "column", "comb", "combine", "comedy", "comfort", "comic", "command", "comment", "common", "community", "company", "compare", "compete", "complete", "complex", "condition", "conduct", "confirm", "connect", "consider", "contain", "content", "contest", "continue", "contract", "control", "cookie", "copper", "copy", "coral", "corner", "cotton", "couch", "cough", "could", "count", "couple", "courage", "court", "cover", "crack", "craft", "crash", "crazy", "create", "credit", "crew", "crime", "crisp", "crisis", "critic", "crop", "cross", "crowd", "crown", "crucial", "cruel", "crush", "cry", "crystal", "cube", "culture", "curious", "current", "curve", "custom", "cycle", "daily", "damage", "damp", "danger", "daring", "data", "dawn", "dead", "deaf", "deal", "debate", "debt", "decade", "decision", "deck", "declare", "decline", "decorate", "decrease", "deer", "defeat", "defend", "define", "degree", "delay", "delete", "deliver", "demand", "dentist", "deny", "depend", "describe", "desert", "design", "detail", "develop", "device", "diamond", "diary", "differ", "difficult", "digital", "direct", "disagree", "disappear", "discover", "discuss", "disease", "dish", "dismiss", "distance", "divide", "document", "doll", "dollar", "dolphin", "double", "doubt", "dozen", "draft", "drag", "drama", "drill", "drip", "drop", "drum", "dry", "duck", "due", "dull", "dust", "duty", "eager", "eagle", "earn", "earth", "ease", "echo", "ecology", "edge", "edit", "editor", "educate", "eel", "effect", "effort", "elbow", "elder", "elect", "electric", "elegant", "element", "elevator", "embrace", "emerge", "emotion", "employ", "empty", "enable", "enemy", "energy", "engine", "enormous", "enter", "entire", "entrance", "entry", "envelope", "environment", "equal", "equipment", "era", "erase", "error", "escape", "essay", "essential", "estate", "estimate", "even", "event", "evil", "exact", "exam", "except", "exchange", "excite", "exhaust", "exist", "exit", "expand", "expect", "expense", "explore", "fabric", "factor", "factory", "fade", "fail", "fair", "faith", "false", "fame", "fancy", "fashion", "fatal", "fault", "fear", "feature", "feather", "feed", "female", "fence", "fetch", "fever", "fiber", "fiction", "field", "fierce", "fight", "figure", "file", "final", "finance", "finger", "firm", "fit", "fix", "flag", "flame", "flash", "flavor", "flight", "flip", "float", "flour", "flow", "flu", "foam", "focus", "fold", "follow", "force", "forest", "forgive", "fork", "fortune", "forward", "fossil", "fox", "frame", "freedom", "freeze", "frequent", "fresh", "frog", "frost", "fuel", "furniture", "future", "gain", "galaxy", "garage", "gas", "gate", "gather", "general", "gentle", "ghost", "giant", "gift", "glad", "glance", "global", "glove", "glue", "goal", "goat", "god", "gold", "golf", "goose", "govern", "grab", "grace", "grade", "grain", "grand", "grass", "grateful", "gray", "greet", "grid", "grief", "grill", "grip", "grocery", "growth", "guard", "guest", "guide", "guilty", "gun", "habit", "hall", "handle", "handsome", "hang", "hardly", "harm", "hawk", "hay", "heal", "heat", "heaven", "heel", "height", "helpful", "hen", "hero", "hesitate", "hidden", "hint", "hip", "hire", "hit", "hold", "hole", "honest", "honey", "honor", "horizon", "horn", "host", "however", "huge", "human", "humble", "hunt", "hurry", "hurt", "hut", "icon", "ideal", "identify", "identity", "idle", "ignore", "ill", "illness", "image", "immediate", "improve", "inch", "include", "income", "increase", "indeed", "index", "indicate", "indoor", "industry", "infant", "inform", "ingredient", "initial", "inject", "ink", "inner", "innocent", "input", "inquiry", "insect", "inside", "inspire", "install", "instant", "instead", "instrument", "insure", "intend", "international", "interrupt", "interview", "invent", "invite", "iron", "isolate", "issue", "item", "ivory", "jail", "jam", "jar", "jealous", "jeans", "jelly", "jewel", "joy", "judge", "jungle", "junior", "kangaroo", "karate", "kayak", "kettle", "keyboard", "kick", "kidney", "kill", "king", "kingdom", "kiss", "kit", "kite", "kitten", "kiwi", "knee", "knock", "knot", "knowledge", "koala", "label", "labor", "laboratory", "lace", "lack", "ladder", "lady", "lake", "lamp", "land", "latest", "launch", "law", "lawn", "lawyer", "layer", "lazy", "lead", "leaf", "league", "leather", "lecture", "legal", "legend", "lemon", "lend", "length", "level", "license", "lie", "lift", "likely", "limit", "link", "lion", "liquid", "list", "load", "loaf", "loan", "local", "locate", "lock", "lonely", "loose", "lord", "loss", "loud", "lovely", "loyal", "luck", "lucky", "lung", "mad", "magic", "magnet", "mail", "major", "male", "mall", "manage", "manner", "marble", "mark", "marry", "mask", "mass", "master", "material", "math", "matter", "maximum", "maybe", "meaning", "measure", "mechanic", "medal", "medical", "medicine", "memory", "mention", "mess", "metal", "method", "mild", "mile", "mind", "mine", "mineral", "minimum", "mirror", "mix", "mobile", "model", "modern", "moment", "monkey", "moral", "mosquito", "most", "motion", "motor", "mud", "muscle", "museum", "mushroom", "mystery", "nail", "nap", "narrow", "nation", "native", "natural", "nature", "naughty", "neat", "necessary", "neck", "needle", "negative", "neighbor", "neither", "nephew", "nerve", "nest", "net", "network", "niece", "noble", "nobody", "none", "noon", "normal", "note", "notice", "novel", "nuclear", "nut", "oak", "obey", "object", "ocean", "odd", "offer", "oil", "okay", "olive", "olympic", "opera", "operate", "opinion", "opposite", "option", "orbit", "ordinary", "organ", "original", "otherwise", "ought", "outdoor", "outer", "outfit", "oven", "owner", "oxygen", "oyster", "pace", "pack", "packet", "pain", "palace", "pale", "pan", "panel", "panic", "parade", "partner", "passenger", "paste", "path", "patient", "pattern", "pause", "peace", "peanut", "pear", "pearl", "perform", "perhaps", "period", "phrase", "physical", "pick", "pie", "pile", "pill", "pilot", "pipe", "pirate", "pitch", "pizza", "plain", "planet", "plastic", "plate", "pleasant", "plenty", "pocket", "poem", "poison", "polite", "political", "population", "port", "position", "possible", "post", "pour", "power", "praise", "pray", "prefer", "prepare", "president", "press", "prevent", "pride", "primary", "prince", "princess", "print", "private", "prize", "probably", "process", "produce", "profession", "professor", "progress", "promise", "promote", "proof", "proper", "protect", "proud", "prove", "public", "pump", "punch", "punish", "pupil", "pure", "purpose", "push", "puzzle", "quality", "quantity", "quarter", "queen", "quiz", "rabbit", "race", "rail", "raise", "random", "range", "rank", "rapid", "rare", "rate", "rather", "reach", "react", "realize", "reason", "receive", "recent", "recipe", "recognize", "record", "reduce", "refer", "reflect", "refuse", "region", "regular", "reject", "relate", "relax", "release", "remain", "remind", "remove", "rent", "repair", "replace", "reply", "report", "request", "require", "rescue", "research", "respect", "result", "reveal", "review", "reward", "rhythm", "rich", "ride", "ring", "rise", "risk", "robot", "rock", "rocket", "role", "roll", "roof", "root", "rope", "rough", "route", "row", "royal", "rubber", "rude", "rush", "safety", "sail", "salary", "sale", "sample", "sand", "satellite", "satisfy", "sauce", "save", "scale", "scare", "scissors", "score", "screen", "search", "season", "seat", "secret", "section", "seed", "seek", "seem", "select", "self", "sense", "sentence", "separate", "serious", "serve", "service", "set", "settle", "several", "severe", "shade", "shadow", "shake", "shall", "shallow", "shape", "sharp", "sheet", "shelf", "shell", "shelter", "shine", "ship", "shock", "shoot", "shoulder", "shout", "shower", "shut", "shy", "side", "sight", "sign", "signal", "silent", "silk", "silly", "silver", "similar", "simple", "since", "sincere", "single", "sink", "size", "skate", "skill", "skin", "sky", "slice", "slide", "slight", "slim", "smart", "smell", "smoke", "smooth", "snack", "snake", "soap", "soccer", "social", "society", "soft", "software", "soil", "soldier", "solid", "solution", "solve", "somebody", "someone", "sometimes", "sort", "soup", "source", "space", "speech", "speed", "spice", "spider", "spirit", "split", "spot", "spread", "square", "stable", "staff", "stage", "stair", "stamp", "star", "state", "steady", "steal", "steam", "steel", "step", "stick", "still", "sting", "stock", "stomach", "stone", "store", "storm", "stove", "straight", "strange", "stranger", "strength", "stress", "stretch", "strict", "strike", "string", "structure", "stuff", "stupid", "style", "successful", "sudden", "suggest", "suit", "support", "suppose", "surface", "surround", "survey", "survive", "suspect", "swim", "swing", "switch", "system", "tail", "tale", "talent", "tank", "tape", "target", "task", "taste", "tax", "tear", "technology", "temperature", "temple", "tent", "term", "text", "theater", "theme", "theory", "thick", "thief", "thin", "though", "thought", "thread", "throat", "throw", "thumb", "thunder", "tie", "tiger", "tight", "till", "tiny", "tip", "title", "toast", "toilet", "tongue", "tool", "topic", "total", "touch", "tour", "tourist", "toward", "tower", "toy", "track", "trade", "tradition", "treat", "trick", "trouble", "truck", "true", "trust", "truth", "try", "tube", "tune", "tunnel", "twin", "typical", "ugly", "unable", "unique", "unit", "universe", "university", "unless", "unlike", "unusual", "update", "upon", "upper", "upset", "upstairs", "urban", "urge", "urgent", "urine", "urn", "used", "user", "usual", "utensil", "valley", "valuable", "value", "van", "variety", "various", "vase", "vast", "vehicle", "verb", "vest", "village", "visitor", "visual", "volcano", "volume", "vote", "voyage", "wage", "wake", "war", "warn", "waste", "wave", "weak", "wealth", "weapon", "web", "wedding", "weed", "weigh", "weight", "wet", "whale", "wheel", "whether", "while", "whisper", "whole", "wide", "wild", "wind", "wine", "wing", "winner", "wire", "wise", "wish", "within", "witness", "wonder", "wood", "wool", "worry", "worse", "worst", "worth", "would", "wound", "wow", "wrap", "yard", "yeah", "yearly", "yet", "yield", "yoga", "youth", "yummy", "zebra", "zero", "zone", "zoom", "zap", "zest", "zigzag", "zinc", "zipper", "aeon", "aerial", "aerobic", "aorta", "akimbo", "aqua", "aquarium", "aquatic", "epic", "episode", "ewe", "ibex", "ion", "ogre", "osmosis", "osprey", "udder", "ugh", "ukulele", "ulcer", "ubiquitous", "urea", "usurp", "uranium", "shark", "shame", "shave", "shift", "shiny", "shore", "shown", "thigh", "thirst", "thirsty", "thorn", "threat", "threw", "chart", "chess", "chew", "chill", "chorus", "trail", "break", "crane", "creek", "trap", "trend", "troop", "grape", "graph", "grin", "plug", "plus", "plum", "spin", "spoil", "spoon", "spray", "sweep", "swift", "skip", "sketch", "smash", "sneak", "snap", "snail", "wheat", "whose", "wrist", "wreck", "wrestle", "wrinkle", "physics", "known", "knit", "blank", "blood", "globe", "glow", "slot", "script", "scrub", "screw", "squad", "squash", "squeeze", "twist", "apricot", "airplane", "album", "absent", "achieve", "action", "active", "actor", "actual", "adjust", "admit", "advise", "against", "agent", "agree", "allow", "almost", "alone", "along", "already", "although", "amazing", "angel", "anger", "angle", "appeal", "beyond", "bottom", "breathe", "central", "climate", "costume", "darkness", "daylight", "department", "difference", "direction", "dragon", "drawer", "easily", "eastern", "education", "elderly", "election", "ending", "especially", "failure", "familiar", "finally", "fitness", "frozen", "garlic", "gesture", "ginger", "gladly", "golden", "government", "grammar", "guarantee", "guidance", "happiness", "harbor", "harmful", "harvest", "hearing", "herself", "highway", "himself", "honesty", "hopeful", "household", "iceberg", "illegal", "importance", "impossible", "independent", "individual", "infection", "influence", "instruction", "intelligent", "introduction", "invitation", "involve", "itself", "jewelry", "joint", "journalist", "joyful", "justice", "kindness", "laptop", "laughter", "leader", "learning", "liberty", "lifetime", "lightning", "listener", "literature", "location", "luggage", "magnetic", "mailbox", "maintain", "majority", "manufacture", "margin", "marine", "marriage", "mathematics", "meadow", "meanwhile", "meeting", "missing", "mixture", "monster", "monthly", "movement", "musical", "musician", "nearby", "nearly", "necklace", "nervous", "neutral", "newspaper", "northern", "nutrition", "observe", "officer", "official", "opportunity", "organize", "package", "painful", "painting", "pancake", "paragraph", "parallel", "parking", "password", "peaceful", "payment", "percent", "performance", "permission", "personal", "personality", "pianist", "picnic", "pillow", "poetry", "positive", "powerful", "practical", "precious", "pressure", "previous", "principal", "professional", "provide", "publish", "quickly", "railway", "rainbow", "rapidly", "rarely", "reaction", "reader", "reading", "recently", "recommend", "relationship", "reliable", "responsible", "retire", "sailor", "scientist", "secretary", "selection", "senior", "shining", "signature", "silence", "sincerely", "singer", "situation", "skillful", "somehow", "somewhere", "speaker", "spelling", "spicy", "splendid", "sponsor", "statue", "storage", "struggle", "suddenly", "suggestion", "suitable", "summary", "sunlight", "supply", "surely", "sweater", "symbol", "sympathy", "talented", "teaching", "teamwork", "temporary", "therefore", "timber", "traditional", "treasure", "treatment", "triangle", "truly", "turkey", "uncomfortable", "underground", "understanding", "union", "united", "unknown", "utility", "vacuum", "version", "victory", "violence", "violin", "vocabulary", "volunteer", "waiting", "wakeful", "wallet", "wander", "warning", "washing", "wasteful", "waterfall", "weakness", "wealthy", "western", "whatever", "whenever", "wherever", "whistle", "wildlife", "wisdom", "wooden", "working", "workout", "worldwide", "worried", "worship", "worthy", "youngster", "zookeeper", "zoology"
        }
                local usedWords = {}
        -- Reddedilen kelimeler ON/OFF ve otomatik yeniden baslatmalarda da hatirlanir.
        local rejectedWords = {}
        local wordStats = { attempted = 0, accepted = 0, rejected = 0 }
        local difficultyMode = "Normal"
        local speedMode = false
        local rareWordsMode = false
        local autoRetryEnabled = true
        local prefixAnalyzerLabel, dictionaryStatsLabel, coverageLabel
        local difficultyButton, speedButton, rareButton, retryButton
        local eventAPI
        pcall(function()
            eventAPI = _G.import("event")
        end)

        local function getRequiredPrefix()
            local player = game:GetService("Players").LocalPlayer
            local gui = player and player:FindFirstChildOfClass("PlayerGui")
            local screen = gui and gui:FindFirstChild("ScreenGui")
            local topBar = screen and screen:FindFirstChild("TopBar")
            local answerInput = topBar and topBar:FindFirstChild("AnswerInput")
            local keys = answerInput and answerInput:FindFirstChild("Keys")
            if not keys then return nil end

            local labels = {}
            for _, object in ipairs(keys:GetDescendants()) do
                if object:IsA("TextLabel") or object:IsA("TextButton") then
                    local value = tostring(object.Text or ""):lower()
                    if value:match("^[a-z]+$") then
                        table.insert(labels, object)
                    end
                end
            end
            table.sort(labels, function(a, b)
                if a.LayoutOrder == b.LayoutOrder then
                    return a.Name < b.Name
                end
                return a.LayoutOrder < b.LayoutOrder
            end)

            local prefix = ""
            for _, label in ipairs(labels) do
                prefix = prefix .. tostring(label.Text):lower()
            end
            prefix = prefix:gsub("[^a-z]", "")
            if #prefix < 1 then return nil end
            -- Oyunun verdigi tum sabit harfleri kullan (ornegin N + E = "ne").
            return prefix
        end

        -- Her strike ImageLabel'inin rengini sirali sekilde oku.
        local function getStrikeColors(screen)
            local bottomBar = screen and screen:FindFirstChild("BottomBar")
            local centerBar = bottomBar and bottomBar:FindFirstChild("CenterBar")
            local strikes = centerBar and centerBar:FindFirstChild("Strikes")
            if not strikes then return nil end

            local images = {}
            for _, object in ipairs(strikes:GetChildren()) do
                if object:IsA("ImageLabel") then
                    table.insert(images, object)
                end
            end
            table.sort(images, function(a, b)
                if a.LayoutOrder == b.LayoutOrder then
                    return a.Name < b.Name
                end
                return a.LayoutOrder < b.LayoutOrder
            end)

            local colors = {}
            for index, object in ipairs(images) do
                colors[index] = object.ImageColor3
            end
            return colors
        end

        local function strikeColorsChanged(before, after)
            if not before or not after then return false end
            for index = 1, math.min(#before, #after) do
                local a, b = before[index], after[index]
                if math.abs(a.R - b.R) > 0.01
                    or math.abs(a.G - b.G) > 0.01
                    or math.abs(a.B - b.B) > 0.01 then
                    return true
                end
            end
            return false
        end

        -- Rakibin harf/prefix bazinda zorlanma suresi.
        local opponentDifficulty = {}
        local opponentSamplePrefix = nil
        local opponentSampleStarted = nil
        local lastOpponentResult = "Henüz veri yok"
        local infoStatusLabel, infoDetailLabel, infoHudGui
        local refreshWordStats, getPrefixCandidateCount

        local function refreshOpponentInfo(isTurn, screen)
            if not infoHudGui or not infoHudGui.Parent then return end
            infoHudGui.Enabled = completeWordsEnabled
            if not completeWordsEnabled then return end

            local choiceList = screen and screen:FindFirstChild("ChoiceList")
            local topBar = screen and screen:FindFirstChild("TopBar")
            local answerInput = topBar and topBar:FindFirstChild("AnswerInput")
            local prefix = getRequiredPrefix()
            local matchActive = (choiceList and choiceList.Visible)
                or (answerInput and answerInput.Visible and prefix ~= nil)

            if not matchActive then
                infoStatusLabel.Text = "MAÇ BEKLENİYOR"
                infoDetailLabel.Text = "Oyun turu başladığında analiz otomatik devreye girecek."
            elseif opponentSamplePrefix and opponentSampleStarted then
                local elapsed = math.clamp(os.clock() - opponentSampleStarted, 0, 16)
                infoStatusLabel.Text = "RAKİP TAKİP EDİLİYOR"
                infoDetailLabel.Text = string.format("İlk harf: %s   |   Rakibin süresi: %.1f / 16 sn\nSon kayıt: %s", opponentSamplePrefix:upper(), elapsed, lastOpponentResult)
            elseif isTurn then
                infoStatusLabel.Text = "SENİN SIRAN"
                refreshWordStats(prefix)
                infoDetailLabel.Text = "Prefix: " .. tostring(prefix and prefix:upper() or "algılanamadı")
                    .. "   |   Aday: " .. tostring(prefix and getPrefixCandidateCount(prefix) or 0)
                    .. "   |   En zor rakip harfi: " .. (function()
                        local best, bestAvg = nil, 0
                        for letter, stats in pairs(opponentDifficulty) do
                            local avg = stats.total / math.max(stats.count, 1)
                            if avg > bestAvg then best, bestAvg = letter, avg end
                        end
                        return best and (best:upper() .. string.format(" (%.1f sn)", bestAvg)) or "veri yok"
                    end)()
            elseif choiceList and choiceList.Visible then
                infoStatusLabel.Text = "RAKİP HARF SEÇİYOR"
                infoDetailLabel.Text = "Seçim ekranı açık; cevap süresi henüz başlamadı."
            else
                infoStatusLabel.Text = "RAKİP TURU BEKLENİYOR"
                infoDetailLabel.Text = "Rakibin cevap ekranı algılanmaya çalışılıyor. " .. lastOpponentResult
            end
        end

        local function finishOpponentSample()
            if opponentSamplePrefix and opponentSampleStarted then
                local elapsed = math.clamp(os.clock() - opponentSampleStarted, 0, 16)
                local stats = opponentDifficulty[opponentSamplePrefix] or { total = 0, count = 0 }
                stats.total = stats.total + elapsed
                stats.count = stats.count + 1
                opponentDifficulty[opponentSamplePrefix] = stats
                lastOpponentResult = string.format("%s: %.1f sn kaydedildi", opponentSamplePrefix:upper(), elapsed)
            end
            opponentSamplePrefix = nil
            opponentSampleStarted = nil
        end

        local function observeOpponent(screen, isTurn)
            local topBar = screen and screen:FindFirstChild("TopBar")
            local answerInput = topBar and topBar:FindFirstChild("AnswerInput")
            local choiceList = screen and screen:FindFirstChild("ChoiceList")
            local prefix = getRequiredPrefix()
            local matchActive = (choiceList and choiceList.Visible)
                or (answerInput and answerInput.Visible and prefix ~= nil)

            -- IsTurn=false only counts as the opponent's turn during an active round.
            local opponentAnswering = matchActive
                and not isTurn
                and answerInput ~= nil
                and answerInput.Visible
                and not (choiceList and choiceList.Visible)
                and prefix ~= nil

            if opponentAnswering then
                -- Rakibin turunda yalnizca ilk verilen harfi ve toplam cevap suresini kaydet.
                -- Rakibin yazdigi sonraki harfler yeni kayit olusturmaz.
                if not opponentSamplePrefix then
                    opponentSamplePrefix = prefix:sub(1, 1)
                    opponentSampleStarted = os.clock()
                end
            else
                finishOpponentSample()
            end
            refreshOpponentInfo(isTurn, screen)
        end

        local function wordRarityScore(word)
            local score = math.max(0, #word - 5) * 2
            for letter in word:gmatch(".") do
                if letter == "x" or letter == "z" or letter == "q" or letter == "j" then
                    score = score + 3
                elseif letter == "v" or letter == "k" or letter == "w" then
                    score = score + 1
                end
            end
            return score
        end

        getPrefixCandidateCount = function(prefix)
            local count = 0
            for _, word in ipairs(WORDS) do
                if #word > #prefix and word:sub(1, #prefix) == prefix
                    and not usedWords[word] and not rejectedWords[word] then
                    count = count + 1
                end
            end
            return count
        end

        refreshWordStats = function(prefix)
            if prefixAnalyzerLabel then
                prefixAnalyzerLabel.Text = string.format("PREFIX ANALYZER  |  %s: %d kelime",
                    tostring(prefix or "--"):upper(), prefix and getPrefixCandidateCount(prefix) or 0)
            end
            if dictionaryStatsLabel then
                dictionaryStatsLabel.Text = string.format("DICTIONARY  %d kelime   |   Deneme %d   Kabul %d   Red %d",
                    #WORDS, wordStats.attempted, wordStats.accepted, wordStats.rejected)
            end
        end

        local function findWord(prefix, excludedWords)
            local candidates = {}
            for _, word in ipairs(WORDS) do
                if #word > #prefix
                    and word:sub(1, #prefix) == prefix
                    and not usedWords[word]
                    and not rejectedWords[word]
                    and not (excludedWords and excludedWords[word]) then
                    table.insert(candidates, word)
                end
            end
            if #candidates == 0 then return nil end

            -- Rakibin zorlandigi harf dizisini strateji puanina dahil et.
            local targetSuffix = nil
            local highestAverage = 0
            for observedPrefix, stats in pairs(opponentDifficulty) do
                if stats.count > 0 then
                    local average = stats.total / stats.count
                    if average > highestAverage then
                        highestAverage = average
                        targetSuffix = observedPrefix
                    end
                end
            end

            table.sort(candidates, function(a, b)
                local aScore, bScore = 0, 0
                local aRare, bRare = wordRarityScore(a), wordRarityScore(b)
                if targetSuffix then
                    if a:sub(-#targetSuffix) == targetSuffix then aScore = aScore + 20 end
                    if b:sub(-#targetSuffix) == targetSuffix then bScore = bScore + 20 end
                end

                if difficultyMode == "Hard" then
                    aScore = aScore + math.min(#a, 12)
                    bScore = bScore + math.min(#b, 12)
                elseif difficultyMode == "Impossible" then
                    aScore = aScore + aRare + math.min(#a, 14)
                    bScore = bScore + bRare + math.min(#b, 14)
                elseif difficultyMode == "Easy" then
                    aScore = aScore - #a
                    bScore = bScore - #b
                else
                    aScore = aScore + (aRare * 0.35) - math.abs(#a - 6)
                    bScore = bScore + (bRare * 0.35) - math.abs(#b - 6)
                end

                if rareWordsMode then
                    aScore = aScore + aRare * 2
                    bScore = bScore + bRare * 2
                end
                if aScore == bScore then
                    if difficultyMode == "Easy" then return #a < #b end
                    return a < b
                end
                return aScore > bScore
            end)
            return candidates[1]
        end

        -- Send real virtual keyboard key events instead of firing the game's internal events.
        local VirtualInputManager = game:GetService("VirtualInputManager")
        local function pressLetter(letter)
            local keyName = string.lower(letter) == "return" and "Return" or string.upper(letter)
            local keyCode = Enum.KeyCode[keyName]
            if not keyCode then return false end

            local keyDown = pcall(function()
                VirtualInputManager:SendKeyEvent(true, keyCode, false, game)
            end)
            if not keyDown then return false end

            task.wait(0.06)
            local keyUp = pcall(function()
                VirtualInputManager:SendKeyEvent(false, keyCode, false, game)
            end)
            return keyUp
        end

        -- Her acilis yeni bir oturum kimligi alir; eski donguler bu kimlikle durdurulur.
        local restartCompleteWords
        local activeRunId = 0
        local function runCompleteWords(runId)
            task.spawn(function()
                local Players = game:GetService("Players")
                local player = Players.LocalPlayer
                local lastPrefix = nil

                while completeWordsEnabled and activeRunId == runId do
                    local screen = player:FindFirstChildOfClass("PlayerGui")
                    screen = screen and screen:FindFirstChild("ScreenGui")
                    local choiceList = screen and screen:FindFirstChild("ChoiceList")
                    local isTurn = player:GetAttribute("IsTurn") == true
                    observeOpponent(screen, isTurn)

                    local answerInput = screen and screen:FindFirstChild("TopBar")
                    answerInput = answerInput and answerInput:FindFirstChild("AnswerInput")
                    local currentPrefix = getRequiredPrefix()
                    local matchActive = (choiceList and choiceList.Visible)
                        or (answerInput and answerInput.Visible and currentPrefix ~= nil)

                    if not matchActive or not isTurn or (choiceList and choiceList.Visible) then
                        lastPrefix = nil
                        task.wait(0.2)
                    else
                        local prefix = getRequiredPrefix()
                        if prefix and prefix ~= lastPrefix then
                            lastPrefix = prefix
                            local attemptedWords = {}
                            local maxAttempts = 3

                            for attempt = 1, maxAttempts do
                                if not completeWordsEnabled or activeRunId ~= runId or player:GetAttribute("IsTurn") ~= true then
                                    break
                                end

                                local word = findWord(prefix, attemptedWords)
                                if not word then break end
                                attemptedWords[word] = true
                                wordStats.attempted = wordStats.attempted + 1
                                refreshWordStats(prefix)

                                local typedSuccessfully = true
                                for index = #prefix + 1, #word do
                                    if not completeWordsEnabled or activeRunId ~= runId or player:GetAttribute("IsTurn") ~= true then
                                        typedSuccessfully = false
                                        break
                                    end
                                    if not pressLetter(word:sub(index, index)) then
                                        typedSuccessfully = false
                                        break
                                    end
                                    task.wait(speedMode and 0.025 or 0.1)
                                end

                                if not typedSuccessfully then break end

                                task.wait(0.15)
                                -- Bu denemeden once 5 strike'in tamamini kaydet.
                                local strikesBefore = getStrikeColors(screen)
                                if not pressLetter("return") then break end

                                -- ChoiceList / IsTurn degisikligi kabul; yeni pembe strike reddedilme demek.
                                local answerGui = screen and screen:FindFirstChild("TopBar")
                                answerGui = answerGui and answerGui:FindFirstChild("AnswerInput")
                                local choiceGui = screen and screen:FindFirstChild("ChoiceList")
                                local answerAccepted = false
                                local answerRejected = false
                                local runCancelled = false
                                for _ = 1, 20 do
                                    task.wait(0.1)
                                    if not completeWordsEnabled or activeRunId ~= runId then
                                        runCancelled = true
                                        break
                                    end
                                    if player:GetAttribute("IsTurn") ~= true then
                                        answerAccepted = true
                                        break
                                    end
                                    if choiceGui and choiceGui.Visible then
                                        answerAccepted = true
                                        break
                                    end
                                    -- Herhangi bir ImageLabel rengi degistiyse bu cevap reddedildi.
                                    local strikesAfter = getStrikeColors(screen)
                                    if strikeColorsChanged(strikesBefore, strikesAfter) then
                                        answerRejected = true
                                        break
                                    end
                                end

                                if runCancelled then
                                    break
                                elseif answerAccepted then
                                    usedWords[word] = true
                                    wordStats.accepted = wordStats.accepted + 1
                                    refreshWordStats(prefix)
                                    break
                                elseif answerRejected then
                                    -- Word Memory: reddedilen kelime sonraki turlarda da secilmez.
                                    usedWords[word] = true
                                    rejectedWords[word] = true
                                    wordStats.rejected = wordStats.rejected + 1
                                    refreshWordStats(prefix)
                                    -- Yanlis cevapta sadece bizim yazdigimiz harfleri sil.
                                    for _ = 1, (#word - #prefix) do
                                        if not pressLetter("backspace") then
                                            typedSuccessfully = false
                                            break
                                        end
                                        task.wait(0.06)
                                    end
                                    if not typedSuccessfully then break end
                                    task.wait(speedMode and 0.04 or 0.12)
                                    -- Auto Retry kapaliysa reddedilen cevaptan sonra bekle.
                                    if autoRetryEnabled and restartCompleteWords then
                                        restartCompleteWords(word)
                                    end
                                    break
                                else
                                    -- Oyun henuz kabul/red sinyali vermediyse metni bozma.
                                    break
                                end
                            end
                        end
                        task.wait(0.12)
                    end
                end
            end)
        end


        local scroll = Instance.new("ScrollingFrame")
        scroll.Name = "CompleteWordsScroll"
        scroll.Position = UDim2.fromOffset(0, 0)
        scroll.Size = UDim2.new(1, 0, 1, 0)
        scroll.BackgroundTransparency = 1
        scroll.BorderSizePixel = 0
        scroll.ScrollBarThickness = 4
        scroll.ScrollBarImageColor3 = Color3.fromRGB(105, 125, 150)
        scroll.ScrollingDirection = Enum.ScrollingDirection.Y
        scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
        scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
        scroll.Active = true
        scroll.Parent = page

        local content = Instance.new("Frame")
        content.Name = "CompleteWordsContent"
        content.Position = UDim2.fromOffset(10, 10)
        content.Size = UDim2.new(1, -20, 0, 0)
        content.AutomaticSize = Enum.AutomaticSize.Y
        content.BackgroundTransparency = 1
        content.Parent = scroll

        local layout = Instance.new("UIListLayout")
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.Padding = UDim.new(0, 10)
        layout.Parent = content

        local card = Instance.new("Frame")
        card.Name = "CompleteWordsCard"
        card.Size = UDim2.new(1, 0, 0, 66)
        card.BackgroundColor3 = CARD
        card.BorderSizePixel = 0
        card.LayoutOrder = 1
        card.Parent = content

        local cardCorner = Instance.new("UICorner")
        cardCorner.CornerRadius = UDim.new(0, 12)
        cardCorner.Parent = card

        local cardGradient = Instance.new("UIGradient")
        cardGradient.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(20, 31, 47)),
            ColorSequenceKeypoint.new(1, PANEL)
        })
        cardGradient.Rotation = 15
        cardGradient.Parent = card

        local cardStroke = Instance.new("UIStroke")
        cardStroke.Name = "WhiteOutline"
        cardStroke.Color = WHITE
        cardStroke.Thickness = 1.35
        cardStroke.Transparency = 0.28
        cardStroke.Parent = card

        -- Complete Words ayarlari ve canli sozluk analiz paneli.
        local controls = Instance.new("Frame")
        controls.Name = "CompleteWordsControls"
        controls.Size = UDim2.new(1, 0, 0, 190)
        controls.BackgroundColor3 = PANEL
        controls.BorderSizePixel = 0
        controls.LayoutOrder = 2
        controls.Parent = content
        local controlsCorner = Instance.new("UICorner")
        controlsCorner.CornerRadius = UDim.new(0, 12)
        controlsCorner.Parent = controls
        local controlsStroke = Instance.new("UIStroke")
        controlsStroke.Color = Color3.fromRGB(70, 165, 245)
        controlsStroke.Transparency = 0.55
        controlsStroke.Parent = controls

        local function makeControlLabel(name, text, position, size, textSize)
            local label = Instance.new("TextLabel")
            label.Name = name
            label.Position = position
            label.Size = size
            label.BackgroundTransparency = 1
            label.Text = text
            label.TextColor3 = TEXT
            label.TextSize = textSize or 10
            label.Font = Enum.Font.GothamMedium
            label.TextXAlignment = Enum.TextXAlignment.Left
            label.Parent = controls
            return label
        end

        local function makeControlButton(name, text, position, size)
            local button = Instance.new("TextButton")
            button.Name = name
            button.Position = position
            button.Size = size
            button.BackgroundColor3 = CARD
            button.BorderSizePixel = 0
            button.Text = text
            button.TextColor3 = WHITE
            button.TextSize = 10
            button.Font = Enum.Font.GothamBold
            button.AutoButtonColor = true
            button.Parent = controls
            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(0, 7)
            corner.Parent = button
            return button
        end

        makeControlLabel("SettingsTitle", "COMPLETE WORDS SETTINGS", UDim2.fromOffset(12, 8), UDim2.new(1, -24, 0, 18), 11)
        difficultyButton = makeControlButton("DifficultyMode", "MODE: NORMAL", UDim2.fromOffset(12, 32), UDim2.new(0.48, -6, 0, 28))
        speedButton = makeControlButton("SpeedMode", "SPEED: OFF", UDim2.new(0.52, 0, 0, 32), UDim2.new(0.48, -12, 0, 28))
        rareButton = makeControlButton("RareWordsMode", "RARE WORDS: OFF", UDim2.fromOffset(12, 66), UDim2.new(0.48, -6, 0, 28))
        retryButton = makeControlButton("AutoRetryMode", "AUTO RETRY: ON", UDim2.new(0.52, 0, 0, 66), UDim2.new(0.48, -12, 0, 28))
        prefixAnalyzerLabel = makeControlLabel("PrefixAnalyzer", "PREFIX ANALYZER  |  bekleniyor", UDim2.fromOffset(12, 102), UDim2.new(1, -24, 0, 18), 10)
        dictionaryStatsLabel = makeControlLabel("DictionaryStats", "DICTIONARY  |  istatistik bekleniyor", UDim2.fromOffset(12, 124), UDim2.new(1, -24, 0, 18), 9)
        coverageLabel = makeControlLabel("PrefixCoverage", "PREFIX COVERAGE  |  hesaplanıyor", UDim2.fromOffset(12, 146), UDim2.new(1, -24, 0, 18), 9)

        local twoPrefixCoverage, threePrefixCoverage = {}, {}
        for _, word in ipairs(WORDS) do
            if #word >= 2 then twoPrefixCoverage[word:sub(1, 2)] = true end
            if #word >= 3 then threePrefixCoverage[word:sub(1, 3)] = true end
        end
        local twoCount, threeCount = 0, 0
        for _ in pairs(twoPrefixCoverage) do twoCount = twoCount + 1 end
        for _ in pairs(threePrefixCoverage) do threeCount = threeCount + 1 end
        coverageLabel.Text = string.format("PREFIX COVERAGE  |  2 harf: %d   3 harf: %d", twoCount, threeCount)

        local modes = { "Easy", "Normal", "Hard", "Impossible" }
        difficultyButton.MouseButton1Click:Connect(function()
            local index = table.find(modes, difficultyMode) or 2
            difficultyMode = modes[index % #modes + 1]
            difficultyButton.Text = "MODE: " .. string.upper(difficultyMode)
        end)
        speedButton.MouseButton1Click:Connect(function()
            speedMode = not speedMode
            speedButton.Text = "SPEED: " .. (speedMode and "ON" or "OFF")
        end)
        rareButton.MouseButton1Click:Connect(function()
            rareWordsMode = not rareWordsMode
            rareButton.Text = "RARE WORDS: " .. (rareWordsMode and "ON" or "OFF")
        end)
        retryButton.MouseButton1Click:Connect(function()
            autoRetryEnabled = not autoRetryEnabled
            retryButton.Text = "AUTO RETRY: " .. (autoRetryEnabled and "ON" or "OFF")
        end)

        -- Independent top HUD, like the Auto Throw status panel.
        local player = game:GetService("Players").LocalPlayer
        local playerGui = player:WaitForChild("PlayerGui")
        infoHudGui = Instance.new("ScreenGui")
        infoHudGui.Name = "BZHUB_CompleteWords_AnalysisHUD"
        infoHudGui.ResetOnSpawn = false
        infoHudGui.IgnoreGuiInset = true
        infoHudGui.DisplayOrder = 100002
        infoHudGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        infoHudGui.Enabled = false
        infoHudGui.Parent = playerGui

        local infoHudPanel = Instance.new("Frame")
        infoHudPanel.Name = "OpponentAnalysisPanel"
        infoHudPanel.AnchorPoint = Vector2.new(0.5, 0)
        infoHudPanel.Position = UDim2.new(0.5, 0, 0, 70)
        infoHudPanel.Size = UDim2.fromOffset(390, 92)
        infoHudPanel.BackgroundColor3 = Color3.fromRGB(8, 13, 22)
        infoHudPanel.BackgroundTransparency = 0.08
        infoHudPanel.BorderSizePixel = 0
        infoHudPanel.Parent = infoHudGui

        local infoHudCorner = Instance.new("UICorner")
        infoHudCorner.CornerRadius = UDim.new(0, 12)
        infoHudCorner.Parent = infoHudPanel

        local infoHudStroke = Instance.new("UIStroke")
        infoHudStroke.Color = Color3.fromRGB(70, 165, 245)
        infoHudStroke.Thickness = 1.2
        infoHudStroke.Transparency = 0.18
        infoHudStroke.Parent = infoHudPanel

        infoStatusLabel = Instance.new("TextLabel")
        infoStatusLabel.Name = "AnalysisStatus"
        infoStatusLabel.Position = UDim2.fromOffset(14, 9)
        infoStatusLabel.Size = UDim2.new(1, -28, 0, 20)
        infoStatusLabel.BackgroundTransparency = 1
        infoStatusLabel.Text = "ANALİZ KAPALI"
        infoStatusLabel.TextColor3 = WHITE
        infoStatusLabel.TextSize = 12
        infoStatusLabel.Font = Enum.Font.GothamBold
        infoStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
        infoStatusLabel.Parent = infoHudPanel

        infoDetailLabel = Instance.new("TextLabel")
        infoDetailLabel.Name = "AnalysisDetails"
        infoDetailLabel.Position = UDim2.fromOffset(14, 32)
        infoDetailLabel.Size = UDim2.new(1, -28, 0, 50)
        infoDetailLabel.BackgroundTransparency = 1
        infoDetailLabel.Text = "Complete Words açıldığında rakip takibi başlayacak."
        infoDetailLabel.TextColor3 = MUTED
        infoDetailLabel.TextSize = 10
        infoDetailLabel.Font = Enum.Font.Gotham
        infoDetailLabel.TextWrapped = true
        infoDetailLabel.TextXAlignment = Enum.TextXAlignment.Left
        infoDetailLabel.TextYAlignment = Enum.TextYAlignment.Top
        infoDetailLabel.Parent = infoHudPanel

        local nameLabel = Instance.new("TextLabel")
        nameLabel.Name = "CompleteWordsLabel"
        nameLabel.Position = UDim2.fromOffset(14, 0)
        nameLabel.Size = UDim2.new(1, -112, 1, 0)
        nameLabel.BackgroundTransparency = 1
        nameLabel.Text = "Complete Words"
        nameLabel.TextColor3 = TEXT
        nameLabel.TextSize = 14
        nameLabel.Font = Enum.Font.GothamBold
        nameLabel.TextXAlignment = Enum.TextXAlignment.Left
        nameLabel.Parent = card

        local stateLabel = Instance.new("TextLabel")
        stateLabel.Name = "CompleteWordsState"
        stateLabel.AnchorPoint = Vector2.new(1, 0.5)
        stateLabel.Position = UDim2.new(1, -91, 0.5, 0)
        stateLabel.Size = UDim2.fromOffset(64, 16)
        stateLabel.BackgroundTransparency = 1
        stateLabel.Text = "OFF"
        stateLabel.TextColor3 = MUTED
        stateLabel.TextSize = 9
        stateLabel.Font = Enum.Font.GothamBold
        stateLabel.TextXAlignment = Enum.TextXAlignment.Right
        stateLabel.Parent = card

        local switch = Instance.new("TextButton")
        switch.Name = "CompleteWordsSwitch"
        switch.AnchorPoint = Vector2.new(1, 0.5)
        switch.Position = UDim2.new(1, -12, 0.5, 0)
        switch.Size = UDim2.fromOffset(62, 28)
        switch.BackgroundColor3 = Color3.fromRGB(43, 53, 68)
        switch.BorderSizePixel = 0
        switch.Text = ""
        switch.AutoButtonColor = false
        switch.Parent = card

        local switchCorner = Instance.new("UICorner")
        switchCorner.CornerRadius = UDim.new(1, 0)
        switchCorner.Parent = switch

        local switchStroke = Instance.new("UIStroke")
        switchStroke.Color = WHITE
        switchStroke.Transparency = 0.35
        switchStroke.Thickness = 1
        switchStroke.Parent = switch

        local knob = Instance.new("Frame")
        knob.Name = "Knob"
        knob.Position = UDim2.fromOffset(3, 3)
        knob.Size = UDim2.fromOffset(22, 22)
        knob.BackgroundColor3 = WHITE
        knob.BorderSizePixel = 0
        knob.Parent = switch

        local knobCorner = Instance.new("UICorner")
        knobCorner.CornerRadius = UDim.new(1, 0)
        knobCorner.Parent = knob

        local function updateSwitch(instant)
            local knobPosition = completeWordsEnabled
                and UDim2.new(1, -25, 0, 3)
                or UDim2.fromOffset(3, 3)
            local switchColor = completeWordsEnabled
                and WHITE
                or Color3.fromRGB(43, 53, 68)
            local knobColor = completeWordsEnabled
                and Color3.fromRGB(18, 24, 34)
                or WHITE

            stateLabel.Text = completeWordsEnabled and "ON" or "OFF"
            stateLabel.TextColor3 = completeWordsEnabled and WHITE or MUTED

            if instant then
                knob.Position = knobPosition
                knob.BackgroundColor3 = knobColor
                switch.BackgroundColor3 = switchColor
                switchStroke.Transparency = completeWordsEnabled and 0.05 or 0.35
            else
                TweenService:Create(knob, TweenInfo.new(0.2, Enum.EasingStyle.Quint), {
                    Position = knobPosition,
                    BackgroundColor3 = knobColor
                }):Play()
                TweenService:Create(switch, TweenInfo.new(0.2, Enum.EasingStyle.Quint), {
                    BackgroundColor3 = switchColor
                }):Play()
                TweenService:Create(switchStroke, TweenInfo.new(0.2, Enum.EasingStyle.Quint), {
                    Transparency = completeWordsEnabled and 0.05 or 0.35
                }):Play()
            end
        end

        restartCompleteWords = function(rejectedWord)
            if not completeWordsEnabled then return end

            -- Eski donguyu aninda durdur ve ozellik dugmesini kisa sureligine OFF yap.
            completeWordsEnabled = false
            activeRunId = activeRunId + 1
            updateSwitch(true)
            if infoHudGui then infoHudGui.Enabled = false end

            task.spawn(function()
                task.wait(0.15)
                -- Yeni oturum: tum analiz ve kullanilmis kelime verileri sifirlanir.
                usedWords = {}
                if rejectedWord then usedWords[rejectedWord] = true end
                opponentDifficulty = {}
                opponentSamplePrefix = nil
                opponentSampleStarted = nil
                lastOpponentResult = "Henüz veri yok"

                completeWordsEnabled = true
                activeRunId = activeRunId + 1
                updateSwitch(true)
                if infoHudGui then infoHudGui.Enabled = true end
                runCompleteWords(activeRunId)
            end)
        end

        switch.MouseButton1Click:Connect(function()
            completeWordsEnabled = not completeWordsEnabled
            activeRunId = activeRunId + 1
            updateSwitch(false)

            if not completeWordsEnabled then
                -- Kapatirken aktif donguyu gecersiz kil ve tum oturum verilerini sifirla.
                opponentSamplePrefix = nil
                opponentSampleStarted = nil
                opponentDifficulty = {}
                lastOpponentResult = "Henüz veri yok"
                usedWords = {}
                if infoHudGui then infoHudGui.Enabled = false end
            else
                -- Her acilista kelime listesi, rakip analizi ve deneme durumu bastan baslar.
                usedWords = {}
                opponentDifficulty = {}
                opponentSamplePrefix = nil
                opponentSampleStarted = nil
                lastOpponentResult = "Henüz veri yok"
                if infoHudGui then infoHudGui.Enabled = true end
                runCompleteWords(activeRunId)
            end
        end)

        difficultyButton.Text = "MODE: " .. string.upper(difficultyMode)
        speedButton.Text = "SPEED: OFF"
        rareButton.Text = "RARE WORDS: OFF"
        retryButton.Text = "AUTO RETRY: ON"
        refreshWordStats(nil)

        updateSwitch(true)
    end)
end

return GameModule
