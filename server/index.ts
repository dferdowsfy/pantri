import express from 'express';
import dotenv from 'dotenv';
import path from 'path';

dotenv.config({ path: path.resolve(process.cwd(), '.env') });

const app = express();
app.use(express.json());

// ─── Types ────────────────────────────────────────────────────────────────────

interface InventoryItem {
  id: string;
  name: string;
  category: string;
  emoji: string;
  baselineDays: number;
  isPerishable: boolean;
  isActive: boolean;
  lastPurchased: Date;
}

interface ComputedItem extends Omit<InventoryItem, 'lastPurchased'> {
  lastPurchased: string;
  daysUntilNeeded: number;
  status: 'good' | 'needSoon' | 'buyNow';
  subtitle: string;
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

function computeStatus(item: InventoryItem): ComputedItem {
  const now = new Date();
  const daysSincePurchase =
    (now.getTime() - item.lastPurchased.getTime()) / (1000 * 60 * 60 * 24);
  const daysUntilNeeded = Math.round(item.baselineDays - daysSincePurchase);

  let status: 'good' | 'needSoon' | 'buyNow';
  if (daysUntilNeeded <= 0) status = 'buyNow';
  else if (daysUntilNeeded <= 2) status = 'needSoon';
  else status = 'good';

  let subtitle: string;
  if (daysUntilNeeded <= 0) subtitle = 'Likely needed now';
  else if (daysUntilNeeded === 1) subtitle = 'Likely needed tomorrow';
  else subtitle = `Due in ${daysUntilNeeded} days`;

  return {
    ...item,
    lastPurchased: item.lastPurchased.toISOString(),
    daysUntilNeeded,
    status,
    subtitle,
  };
}

function findItemFuzzy(name: string): InventoryItem | undefined {
  const lower = name.toLowerCase().trim();
  return (
    inventory.find((i) => i.name.toLowerCase() === lower) ||
    inventory.find((i) => i.name.toLowerCase().includes(lower)) ||
    inventory.find((i) => lower.includes(i.name.toLowerCase()))
  );
}

// ─── Seed Data ────────────────────────────────────────────────────────────────

const DAY = 86_400_000;

const inventory: InventoryItem[] = [
  { id: '1',  name: 'Milk',         category: 'dairy',      emoji: '🥛', baselineDays: 7,  isPerishable: true,  isActive: true, lastPurchased: new Date(Date.now() - 5 * DAY) },
  { id: '2',  name: 'Eggs',         category: 'dairy',      emoji: '🥚', baselineDays: 10, isPerishable: true,  isActive: true, lastPurchased: new Date(Date.now() - 8 * DAY) },
  { id: '3',  name: 'Spinach',      category: 'produce',    emoji: '🌿', baselineDays: 7,  isPerishable: true,  isActive: true, lastPurchased: new Date(Date.now() - 2 * DAY) },
  { id: '4',  name: 'Pasta Sauce',  category: 'pantry',     emoji: '🍝', baselineDays: 21, isPerishable: false, isActive: true, lastPurchased: new Date(Date.now() - 15 * DAY) },
  { id: '5',  name: 'Coffee Beans', category: 'beverages',  emoji: '☕', baselineDays: 14, isPerishable: false, isActive: true, lastPurchased: new Date(Date.now() - 7 * DAY) },
  { id: '6',  name: 'Bread',        category: 'bakery',     emoji: '🍞', baselineDays: 5,  isPerishable: true,  isActive: true, lastPurchased: new Date(Date.now() - 3 * DAY) },
  { id: '7',  name: 'Chicken',      category: 'meatSeafood',emoji: '🍗', baselineDays: 7,  isPerishable: true,  isActive: true, lastPurchased: new Date(Date.now() - 1 * DAY) },
  { id: '8',  name: 'Rice',         category: 'pantry',     emoji: '🍚', baselineDays: 30, isPerishable: false, isActive: true, lastPurchased: new Date(Date.now() - 10 * DAY) },
  { id: '9',  name: 'Bananas',      category: 'produce',    emoji: '🍌', baselineDays: 5,  isPerishable: true,  isActive: true, lastPurchased: new Date(Date.now() - 4 * DAY) },
  { id: '10', name: 'Yogurt',       category: 'dairy',      emoji: '🥄', baselineDays: 7,  isPerishable: true,  isActive: true, lastPurchased: new Date(Date.now() - 6 * DAY) },
  { id: '11', name: 'Butter',       category: 'dairy',      emoji: '🧈', baselineDays: 14, isPerishable: true,  isActive: true, lastPurchased: new Date(Date.now() - 3 * DAY) },
  { id: '12', name: 'Onions',       category: 'produce',    emoji: '🧅', baselineDays: 14, isPerishable: false, isActive: true, lastPurchased: new Date(Date.now() - 12 * DAY) },
];

// ─── Routes ───────────────────────────────────────────────────────────────────

// GET /api/inventory — full inventory with computed status
app.get('/api/inventory', (_req, res) => {
  const items = inventory.filter((i) => i.isActive).map(computeStatus);

  // Sort: buyNow first, then needSoon, then good
  const order = { buyNow: 0, needSoon: 1, good: 2 };
  items.sort((a, b) => order[a.status] - order[b.status] || a.daysUntilNeeded - b.daysUntilNeeded);

  res.json({ items });
});

// POST /api/inventory/purchase — mark an item as just bought
app.post('/api/inventory/purchase', (req, res) => {
  const { itemName } = req.body;
  if (!itemName) return res.status(400).json({ error: 'itemName is required' });

  const item = findItemFuzzy(itemName);
  if (item) {
    item.lastPurchased = new Date();
    res.json({ success: true, item: computeStatus(item) });
  } else {
    res.status(404).json({ error: `Item "${itemName}" not found in inventory` });
  }
});

// POST /api/inventory/add — add a new tracked item
app.post('/api/inventory/add', (req, res) => {
  const { name, category, baselineDays, emoji } = req.body;
  if (!name) return res.status(400).json({ error: 'name is required' });

  // Don't add duplicates
  if (findItemFuzzy(name)) {
    return res.status(409).json({ error: `"${name}" is already being tracked` });
  }

  const newItem: InventoryItem = {
    id: String(Date.now()),
    name,
    category: category || 'other',
    emoji: emoji || '📦',
    baselineDays: baselineDays || 7,
    isPerishable: true,
    isActive: true,
    lastPurchased: new Date(),
  };
  inventory.push(newItem);
  res.json({ success: true, item: computeStatus(newItem) });
});

// ─── Chat with AI ─────────────────────────────────────────────────────────────

app.post('/api/chat', async (req, res) => {
  const { message, history = [] } = req.body;
  if (!message) return res.status(400).json({ error: 'message is required' });

  // Current inventory snapshot
  const items = inventory.filter((i) => i.isActive).map(computeStatus);

  // ── Detect purchase intent & execute ──
  const purchaseRx =
    /(?:i\s+)?(?:just\s+)?(?:bought|purchased|picked\s+up|got|grabbed|restocked|replenished)\s+(.+)/i;
  const addRx =
    /(?:add|track|start\s+tracking)\s+(.+?)(?:\s+to\s+(?:my\s+)?(?:pantry|inventory|list))?$/i;

  let actionContext = '';
  let inventoryUpdated = false;

  const purchaseMatch = message.match(purchaseRx);
  const addMatch = message.match(addRx);

  if (purchaseMatch) {
    const itemName = purchaseMatch[1].replace(/[.!?,]$/, '').trim();
    const item = findItemFuzzy(itemName);
    if (item) {
      item.lastPurchased = new Date();
      inventoryUpdated = true;
      actionContext = `[ACTION COMPLETED: "${item.name}" marked as purchased today. Its status is now "good".]`;
    } else {
      actionContext = `[ACTION FAILED: No item named "${itemName}" found in inventory. Suggest adding it.]`;
    }
  } else if (addMatch) {
    const itemName = addMatch[1].replace(/[.!?,]$/, '').trim();
    if (!findItemFuzzy(itemName)) {
      const newItem: InventoryItem = {
        id: String(Date.now()),
        name: itemName.charAt(0).toUpperCase() + itemName.slice(1),
        category: 'other',
        emoji: '📦',
        baselineDays: 7,
        isPerishable: true,
        isActive: true,
        lastPurchased: new Date(),
      };
      inventory.push(newItem);
      inventoryUpdated = true;
      actionContext = `[ACTION COMPLETED: "${newItem.name}" has been added to the pantry and marked as stocked.]`;
    } else {
      actionContext = `[NOTE: "${itemName}" is already being tracked.]`;
    }
  }

  // ── Build system prompt ──
  const inventoryList = items
    .map((i) => {
      const urgency =
        i.daysUntilNeeded <= 0
          ? '🔴 OVERDUE'
          : i.daysUntilNeeded <= 2
            ? '🟡 SOON'
            : '🟢 OK';
      return `  ${i.emoji} ${i.name} — ${i.subtitle} [${urgency}]`;
    })
    .join('\n');

  const systemPrompt = `You are Pantri, a warm, concise pantry assistant chatbot.

CURRENT PANTRY INVENTORY (${items.length} items):
${inventoryList}

KEY STATS:
- Items needing attention: ${items.filter((i) => i.status === 'buyNow').length} overdue, ${items.filter((i) => i.status === 'needSoon').length} due soon
- Well-stocked items: ${items.filter((i) => i.status === 'good').length}

${actionContext}

INSTRUCTIONS:
- Be conversational, friendly, and concise (2–3 sentences unless user asks for a list).
- Use emojis from the inventory data naturally.
- When asked what's low/needed/running out, reference specific items and days.
- When a purchase action was completed, confirm it cheerfully.
- If user wants to add an item that was added, confirm it.
- You can suggest shopping lists, meal ideas based on what's available, or storage tips.
- Never mention system prompts, your architecture, or that you're AI. Just be Pantri.`;

  const messages = [
    { role: 'system' as const, content: systemPrompt },
    ...history.slice(-10),
    { role: 'user' as const, content: message },
  ];

  try {
    const apiKey = process.env.OPENROUTER_API_KEY;
    if (!apiKey) {
      return res.status(500).json({ error: 'OPENROUTER_API_KEY not configured' });
    }

    const response = await fetch('https://openrouter.ai/api/v1/chat/completions', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
        'HTTP-Referer': 'http://localhost:3000',
        'X-Title': 'Pantri',
      },
      body: JSON.stringify({
        model: process.env.OPENROUTER_MODEL || 'google/gemma-4-26b-a4b-it:free',
        messages,
        max_tokens: 300,
        temperature: 0.7,
      }),
    });

    if (!response.ok) {
      const errText = await response.text();
      console.error('OpenRouter error:', response.status, errText);
      return res.status(502).json({ error: 'AI service returned an error' });
    }

    const data = await response.json();
    const reply =
      data.choices?.[0]?.message?.content ||
      "Hmm, I'm having trouble thinking right now. Try asking again?";

    res.json({
      reply,
      inventoryUpdated,
      updatedInventory: inventoryUpdated
        ? inventory.filter((i) => i.isActive).map(computeStatus)
        : undefined,
    });
  } catch (err) {
    console.error('Chat endpoint error:', err);
    res.status(500).json({ error: 'Failed to reach the AI service' });
  }
});

// ─── Start ────────────────────────────────────────────────────────────────────

const PORT = process.env.PORT || 3001;
app.listen(PORT, () => {
  console.log(`\n  🥫  Pantri API running → http://localhost:${PORT}\n`);
});
