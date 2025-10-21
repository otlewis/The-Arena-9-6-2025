# Arena Debate Tutor AI Agent 🎓

An interactive AI debate coach powered by your local qwen3:30b model that helps users practice and improve their debate skills.

## Overview

This AI tutor provides personalized debate coaching through multiple teaching modes. Users can practice arguments, get feedback, learn strategy, and improve their skills - all powered by your local AI model running on Ollama.

## Setup Instructions

### 1. Import the n8n Workflow

```bash
# In n8n UI at http://50.21.187.76:5678
1. Click "Add workflow" → "Import from File"
2. Select: n8n-debate-tutor-agent.json
3. Activate the workflow (toggle must be GREEN)
```

### 2. Webhook URL

After activation:
```
http://50.21.187.76/webhook/debate-tutor
```

## Tutor Modes

The AI tutor supports 6 different coaching modes:

| Mode | Description | Use Case |
|------|-------------|----------|
| **practice** | AI debates against you | Practice arguments in real-time |
| **critique** | Analyzes your argument | Get detailed feedback |
| **research** | Suggests arguments & evidence | Prepare for debates |
| **strategy** | Tactical debate coaching | Learn winning tactics |
| **tips** | General debate advice | Skill improvement |
| **fallacies** | Identifies logical fallacies | Avoid reasoning errors |

## API Usage

### Request Format

**POST** `http://50.21.187.76/webhook/debate-tutor`

**Headers:**
```json
{
  "Content-Type": "application/json"
}
```

**Body:**
```json
{
  "userId": "user_123",
  "sessionId": "session_abc",
  "tutorMode": "practice",
  "topic": "Should social media be regulated?",
  "position": "affirmative",
  "skillLevel": "intermediate",
  "userMessage": "Social media spreads misinformation that harms democracy"
}
```

### Parameters

| Parameter | Type | Required | Options | Default |
|-----------|------|----------|---------|---------|
| `userId` | string | Yes | Any user ID | - |
| `sessionId` | string | No | Any session ID | `new_session` |
| `tutorMode` | string | No | See modes above | `practice` |
| `topic` | string | No | Any debate topic | Empty |
| `position` | string | No | `affirmative`, `negative` | `affirmative` |
| `skillLevel` | string | No | `beginner`, `intermediate`, `advanced` | `intermediate` |
| `userMessage` | string | Yes | User's argument/question | - |

### Response Format

```json
{
  "success": true,
  "tutorResponse": "That's a strong opening argument! Here's my counter...",
  "sessionId": "session_abc",
  "userId": "user_123",
  "tutorMode": "practice",
  "topic": "Should social media be regulated?",
  "position": "affirmative",
  "skillLevel": "intermediate",
  "timestamp": "2025-01-12T10:30:00.000Z",
  "model": "qwen3:30b"
}
```

## Flutter Integration Examples

### Example 1: Practice Mode - Debate with AI

```dart
class DebateTutorScreen extends StatefulWidget {
  @override
  State<DebateTutorScreen> createState() => _DebateTutorScreenState();
}

class _DebateTutorScreenState extends State<DebateTutorScreen> {
  final TextEditingController _messageController = TextEditingController();
  final List<Map<String, String>> _conversation = [];
  bool _isLoading = false;

  String _selectedMode = 'practice';
  String _topic = '';
  String _position = 'affirmative';
  String _skillLevel = 'intermediate';

  Future<void> _sendToTutor(String message) async {
    setState(() {
      _conversation.add({'sender': 'user', 'message': message});
      _isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse('http://50.21.187.76/webhook/debate-tutor'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': _currentUser!.id,
          'sessionId': _sessionId,
          'tutorMode': _selectedMode,
          'topic': _topic,
          'position': _position,
          'skillLevel': _skillLevel,
          'userMessage': message,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        setState(() {
          _conversation.add({
            'sender': 'tutor',
            'message': data['tutorResponse']
          });
          _isLoading = false;
        });
      }
    } catch (e) {
      AppLogger().error('Tutor error: $e');
      setState(() => _isLoading = false);
    }

    _messageController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Debate Tutor'),
        actions: [
          // Mode selector
          PopupMenuButton<String>(
            initialValue: _selectedMode,
            onSelected: (mode) => setState(() => _selectedMode = mode),
            itemBuilder: (context) => [
              PopupMenuItem(value: 'practice', child: Text('Practice')),
              PopupMenuItem(value: 'critique', child: Text('Critique')),
              PopupMenuItem(value: 'research', child: Text('Research')),
              PopupMenuItem(value: 'strategy', child: Text('Strategy')),
              PopupMenuItem(value: 'tips', child: Text('Tips')),
              PopupMenuItem(value: 'fallacies', child: Text('Fallacies')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Topic and position selector
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(labelText: 'Topic'),
                    onChanged: (value) => _topic = value,
                  ),
                ),
                SizedBox(width: 16),
                DropdownButton<String>(
                  value: _position,
                  items: [
                    DropdownMenuItem(value: 'affirmative', child: Text('For')),
                    DropdownMenuItem(value: 'negative', child: Text('Against')),
                  ],
                  onChanged: (value) => setState(() => _position = value!),
                ),
              ],
            ),
          ),

          // Conversation history
          Expanded(
            child: ListView.builder(
              itemCount: _conversation.length,
              itemBuilder: (context, index) {
                final msg = _conversation[index];
                final isUser = msg['sender'] == 'user';

                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isUser ? Colors.blue[100] : Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    constraints: BoxConstraints(maxWidth: 300),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isUser ? 'You' : 'AI Tutor',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(msg['message']!),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Loading indicator
          if (_isLoading)
            Padding(
              padding: EdgeInsets.all(8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(strokeWidth: 2),
                  SizedBox(width: 12),
                  Text('AI Tutor is thinking...'),
                ],
              ),
            ),

          // Input field
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: _getHintText(),
                      border: OutlineInputBorder(),
                    ),
                    maxLines: null,
                    onSubmitted: (_) => _sendToTutor(_messageController.text),
                  ),
                ),
                SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.send),
                  onPressed: () => _sendToTutor(_messageController.text),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getHintText() {
    switch (_selectedMode) {
      case 'practice':
        return 'Make your argument...';
      case 'critique':
        return 'Paste your argument for feedback...';
      case 'research':
        return 'What do you want to research?';
      case 'strategy':
        return 'Ask about strategy...';
      case 'fallacies':
        return 'Paste text to check for fallacies...';
      default:
        return 'Ask your question...';
    }
  }
}
```

### Example 2: Quick Critique Button

```dart
// Add to Arena screen after debate ends
void _getCritiqueFromTutor() async {
  // Get user's debate performance data
  final myArguments = "..."; // Collect user's spoken arguments

  final response = await http.post(
    Uri.parse('http://50.21.187.76/webhook/debate-tutor'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'userId': _currentUser!.id,
      'tutorMode': 'critique',
      'topic': widget.topic,
      'position': myRole.contains('affirmative') ? 'affirmative' : 'negative',
      'skillLevel': 'intermediate',
      'userMessage': myArguments,
    }),
  );

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('AI Tutor Feedback'),
        content: SingleChildScrollView(
          child: Text(data['tutorResponse']),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Thanks!'),
          ),
        ],
      ),
    );
  }
}
```

### Example 3: Pre-Debate Research Helper

```dart
// Show before user enters a debate
void _showDebatePrep(String topic, String position) async {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Prepare for Debate'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ElevatedButton(
            onPressed: () async {
              final response = await http.post(
                Uri.parse('http://50.21.187.76/webhook/debate-tutor'),
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode({
                  'userId': _currentUser!.id,
                  'tutorMode': 'research',
                  'topic': topic,
                  'position': position,
                  'skillLevel': 'intermediate',
                  'userMessage': 'Help me prepare arguments for this debate',
                }),
              );

              if (response.statusCode == 200) {
                final data = jsonDecode(response.body);
                Navigator.pop(context);
                _showTutorResponse(data['tutorResponse']);
              }
            },
            child: Text('Get AI Research Help'),
          ),
          SizedBox(height: 8),
          ElevatedButton(
            onPressed: () async {
              final response = await http.post(
                Uri.parse('http://50.21.187.76/webhook/debate-tutor'),
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode({
                  'userId': _currentUser!.id,
                  'tutorMode': 'strategy',
                  'topic': topic,
                  'position': position,
                  'skillLevel': 'intermediate',
                  'userMessage': 'What strategy should I use?',
                }),
              );

              if (response.statusCode == 200) {
                final data = jsonDecode(response.body);
                Navigator.pop(context);
                _showTutorResponse(data['tutorResponse']);
              }
            },
            child: Text('Get Strategy Tips'),
          ),
        ],
      ),
    ),
  );
}
```

## Example Tutor Responses

### Practice Mode
```
User: "Social media spreads misinformation that harms democracy"

Tutor: "That's a compelling opening! However, I'd counter that censoring
social media also harms democracy by restricting free speech. Who decides
what's 'misinformation'? Governments? Tech companies? Both have conflicts
of interest.

**Feedback on your argument:**
✓ Strong: You identified a real problem (misinformation)
✓ Strong: Connected it to a core value (democracy)
✗ Needs work: Didn't provide specific evidence or examples
✗ Needs work: Didn't address how regulation would actually work

**Challenge:** Can you provide 2-3 specific examples of misinformation
campaigns and explain exactly how regulation would have prevented them
without suppressing legitimate debate?"
```

### Critique Mode
```
User: "We should ban TikTok because China uses it to spy on Americans"

Tutor: **Strength of Logic: 6/10**
Your argument assumes correlation equals causation. Just because TikTok
is Chinese-owned doesn't prove spying is happening.

**Evidence Quality: 4/10**
You need concrete evidence. Have there been documented cases? What do
cybersecurity experts say?

**Persuasiveness: 5/10**
Appeals to fear without proof. Opponents will ask for evidence.

**Potential Weaknesses:**
- "What about American apps that collect data?"
- "Is this really about security or trade protectionism?"
- "How is this different from Facebook selling data?"

**Improvement Suggestions:**
1. Lead with documented security incidents
2. Compare TikTok's data practices to US apps
3. Frame as "data sovereignty" not just "China bad"
4. Propose specific security requirements, not just bans
```

### Research Mode
```
User: "Help me argue FOR universal basic income"

Tutor: **Strong Arguments for UBI:**

1. **Poverty Reduction**
   - Finland pilot: 46% less stress, better wellbeing
   - Alaska's dividend: reduced poverty without reducing work
   - Kenya experiment: entrepreneurship increased 12%

2. **Automation Preparation**
   - McKinsey: 45% of jobs automatable by 2030
   - UBI cushions transition to new economy
   - Frees people to retrain

3. **Economic Efficiency**
   - Eliminates welfare bureaucracy (saves 15-20% admin costs)
   - Removes means-testing stigma
   - Stimulates local economies (multiplier effect)

4. **Health & Education Benefits**
   - Reduced ER visits (Canada study)
   - Higher high school graduation rates
   - Less crime (more economic security)

**Key Evidence to Research:**
- Finnish UBI pilot results (2017-2018)
- Alaska Permanent Fund outcomes
- GiveDirectly Kenya study
- Y Combinator Oakland pilot

**Counterarguments You'll Face:**
- "People will stop working" (research shows 1-2% reduction max)
- "Too expensive" (could replace existing welfare + tax reform)
- "Causes inflation" (not if supply can meet demand)

**Strategic Advice:**
Lead with data from real pilots, not theory. Show UBI complements work,
doesn't replace it. Frame as "freedom to choose" not "handout."
```

## Skill Levels

The tutor adapts its teaching style based on skill level:

### Beginner
- Simple explanations
- Encouraging tone
- Basic concepts only
- Step-by-step guidance

### Intermediate (Default)
- Moderate complexity
- Challenges user to think deeper
- Some technical terms
- Constructive criticism

### Advanced
- Complex analysis
- High-level tactics
- Expects strong arguments
- Detailed strategic thinking

## Use Cases in Arena App

### 1. Practice Room
- Create a "Practice with AI" option
- Users practice debates solo before real matches
- AI plays opposing side
- Instant feedback

### 2. Pre-Debate Prep
- Show tutor button before joining debates
- Get quick research & strategy tips
- Build confidence

### 3. Post-Debate Review
- After losing a debate, get AI analysis
- Learn from mistakes
- Improve for next time

### 4. Learning Center
- Dedicated "Debate School" section
- Tutorials on different skills
- Practice exercises
- Track improvement

### 5. Argument Builder
- Help users write stronger challenges
- Review before sending
- Avoid logical fallacies

## Performance

- **Response Time:** 10-30 seconds
- **Model:** qwen3:30b (18GB)
- **Quality:** Excellent reasoning, nuanced feedback
- **Cost:** FREE (local processing)

## Privacy & Security

✅ **Local Processing** - All coaching happens on your server
✅ **No Data Sharing** - Nothing sent to cloud APIs
✅ **Private Learning** - User practice stays confidential
✅ **Full Control** - You own the AI model

## Future Enhancements

- [ ] Save conversation history to Appwrite
- [ ] Track user improvement over time
- [ ] Personalized learning paths
- [ ] Voice input/output for practice
- [ ] Debate scenario library
- [ ] Gamification (XP, badges for practice)
- [ ] Multi-turn debate simulations
- [ ] Tournament preparation mode

## Troubleshooting

### Slow responses
- Normal for 30B parameter model
- First request loads model (~20s)
- Consider using llama3.2:3b for faster responses

### Generic responses
- Make sure topic and position are filled
- Provide specific arguments, not vague statements
- Use appropriate tutorMode for your goal

### Out of memory errors
- qwen3:30b needs ~20GB RAM
- Use llama3.2:3b (only 3GB) instead
- Edit workflow, change model to `llama3.2:3b`

---

**Created:** 2025-01-12
**Model:** qwen3:30b via Ollama
**Platform:** n8n Automation
**Purpose:** Debate skill development & practice
