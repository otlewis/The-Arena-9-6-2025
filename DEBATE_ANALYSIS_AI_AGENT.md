# Arena Debate Analysis AI Agent

AI-powered debate analysis using your local qwen3:30b model via Ollama and n8n.

## Overview

This AI agent analyzes completed Arena debates and provides intelligent insights, summaries, and recommendations using your locally-hosted qwen3:30b language model.

## Setup Instructions

### 1. Import the n8n Workflow

```bash
# In n8n UI at http://50.21.187.76:5678
1. Click "Add workflow" → "Import from File"
2. Select: n8n-debate-analysis-agent.json
3. Activate the workflow (toggle must be GREEN)
```

### 2. Verify Ollama is Running

```bash
# Check Ollama status
curl http://localhost:11434/api/tags

# Should return list of models including qwen3:30b
```

### 3. Webhook URL

After activation, the webhook will be available at:
```
http://50.21.187.76/webhook/analyze-debate
```

## API Usage

### Request Format

**POST** `http://50.21.187.76/webhook/analyze-debate`

**Headers:**
```json
{
  "Content-Type": "application/json"
}
```

**Body:**
```json
{
  "roomId": "room_123abc",
  "analysisType": "full",
  "debateData": {
    // Optional: Additional context about the debate
    "transcript": "...",
    "participants": ["user1", "user2"]
  }
}
```

### Analysis Types

| Type | Description | Use Case |
|------|-------------|----------|
| `full` | Comprehensive debate analysis | Post-debate review |
| `summary` | Brief 2-3 sentence summary | Quick overview |
| `strengths` | Strengths/weaknesses breakdown | Debater feedback |
| `recommendations` | Tips for future debaters | Learning |

### Response Format

```json
{
  "success": true,
  "roomId": "room_123abc",
  "analysis": "# Debate Analysis\n\n## Overview\n...",
  "debateContext": {
    "topic": "Should AI replace human moderators?",
    "winner": "affirmative",
    "affirmativeScore": 85,
    "negativeScore": 72,
    "status": "completed"
  },
  "generatedAt": "2025-01-12T10:30:00.000Z",
  "model": "qwen3:30b",
  "analysisType": "full"
}
```

## Flutter Integration Examples

### Example 1: Full Debate Analysis

```dart
Future<Map<String, dynamic>> analyzeDebate(String roomId) async {
  final response = await http.post(
    Uri.parse('http://50.21.187.76/webhook/analyze-debate'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'roomId': roomId,
      'analysisType': 'full',
    }),
  );

  if (response.statusCode == 200) {
    return jsonDecode(response.body);
  }
  throw Exception('Analysis failed');
}

// Usage in Arena screen after debate ends
void _showDebateAnalysis() async {
  try {
    final analysis = await analyzeDebate(widget.roomId);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('AI Debate Analysis'),
        content: SingleChildScrollView(
          child: MarkdownBody(data: analysis['analysis']),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  } catch (e) {
    AppLogger().error('Failed to analyze debate: $e');
  }
}
```

### Example 2: Quick Summary

```dart
Future<String> getDebateSummary(String roomId) async {
  final response = await http.post(
    Uri.parse('http://50.21.187.76/webhook/analyze-debate'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'roomId': roomId,
      'analysisType': 'summary',
    }),
  );

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    return data['analysis'];
  }
  return 'Analysis unavailable';
}

// Show summary after debate
void _onDebateEnded() async {
  final summary = await getDebateSummary(widget.roomId);

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(summary),
      duration: Duration(seconds: 10),
      action: SnackBarAction(
        label: 'Full Analysis',
        onPressed: _showDebateAnalysis,
      ),
    ),
  );
}
```

### Example 3: Participant Feedback

```dart
Future<void> sendParticipantFeedback(String roomId) async {
  final response = await http.post(
    Uri.parse('http://50.21.187.76/webhook/analyze-debate'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'roomId': roomId,
      'analysisType': 'strengths',
    }),
  );

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);

    // Show feedback to debaters
    _showFeedbackDialog(data['analysis']);
  }
}
```

## What the AI Analyzes

### Full Analysis Includes:

1. **Overview** - Summary of debate outcome
2. **Winner Analysis** - Why one side won (if applicable)
3. **Arguments** - Key points from both sides
4. **Evidence Quality** - Strength of reasoning and sources
5. **Persuasion** - Speaking effectiveness
6. **Recommendations** - How to improve
7. **Rating** - Overall debate quality (1-10)

### Strengths Analysis Includes:

- Top 3 strengths for affirmative side
- Top 3 strengths for negative side
- Key weaknesses for each side
- Areas for improvement

### Recommendations Include:

- Key lessons learned
- Best practices demonstrated
- Common pitfalls to avoid
- Tips for this topic

## AI Model Information

**Model:** qwen3:30b (Qwen 3, 30 billion parameters)
- **Size:** 18 GB
- **Strengths:** Excellent reasoning, long context, multilingual
- **Response Time:** ~10-30 seconds (local processing)
- **Cost:** FREE (runs on your server)

## Performance Notes

- **First request** may take longer (~30s) as model loads
- **Subsequent requests** are faster (~10-15s)
- **Memory usage** ~20GB RAM when active
- **Concurrent requests** limited by server resources

## Troubleshooting

### "Connection refused" error
```bash
# Check if Ollama is running
ollama list

# If not running, start it
ollama serve
```

### Slow responses
- qwen3:30b is a large model, 10-30s response time is normal
- For faster responses, use llama3.2:3b instead (edit workflow)
- Consider upgrading server RAM for better performance

### Model not found
```bash
# Pull the model if needed
ollama pull qwen3:30b
```

### n8n workflow errors
1. Check workflow is activated (green toggle)
2. Verify Ollama URL: `http://localhost:11434`
3. Check Appwrite credentials are correct

## Future Enhancements

- [ ] Save analyses to Appwrite for history
- [ ] Real-time analysis during debates
- [ ] Multi-language support
- [ ] Comparison with previous debates
- [ ] Debater skill tracking over time
- [ ] Automated judge scoring suggestions

## Privacy & Security

✅ **Local Processing** - All AI analysis happens on your server
✅ **No Cloud APIs** - No data sent to OpenAI, Anthropic, etc.
✅ **No Costs** - Completely free to run
✅ **Full Control** - You own the model and data

## Example Analysis Output

```markdown
# Debate Analysis

## Overview
This debate on "Should AI replace human moderators?" was closely contested,
with the affirmative side winning 85-72. Both teams demonstrated strong
argumentation skills with compelling evidence.

## Why Affirmative Won
1. **Stronger Evidence** - Cited 3 peer-reviewed studies on AI moderation effectiveness
2. **Better Rebuttals** - Effectively countered bias concerns with transparency solutions
3. **Clear Framework** - Established clear criteria for success early

## Key Arguments

### Affirmative Highlights:
- AI scales better (24/7 availability)
- Consistency in rule enforcement
- Cost efficiency for platforms

### Negative Highlights:
- Human judgment for nuanced cases
- Cultural context understanding
- Bias in AI training data

## Evidence Quality: 8/10
Both sides used credible sources. Affirmative had slightly more recent studies.

## Persuasion Effectiveness: 9/10
Excellent speaking clarity on both sides. Minimal distracting mannerisms.

## Recommendations
1. **For Future Debaters:** Pre-research counterarguments to your own position
2. **Best Practice:** The affirmative's use of concrete examples was very effective
3. **Avoid:** Don't dismiss opponent's concerns - address them directly

## Overall Assessment: 8.5/10
High-quality debate with strong preparation from both sides. Great learning opportunity.
```

---

**Created:** 2025-01-12
**Model:** qwen3:30b via Ollama
**Platform:** n8n Automation
