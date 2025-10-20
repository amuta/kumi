import * as vscode from 'vscode';
import * as fs from 'fs';
import * as path from 'path';

interface FunctionDef {
  id: string;
  arity: number;
  params: Array<{ name: string }>;
  dtype: any;
  kernels: Record<string, string>;
  aliases: string[];
  kind?: string;
}

let functionsData: Record<string, FunctionDef> = {};

export function activate(context: vscode.ExtensionContext) {
  // Load functions reference JSON from kumi/docs/
  const refPath = path.join(
    context.extensionPath,
    '..',
    '..',
    'docs',
    'functions-reference.json'
  );

  try {
    if (fs.existsSync(refPath)) {
      const content = fs.readFileSync(refPath, 'utf-8');
      functionsData = JSON.parse(content);
      console.log('Kumi functions reference loaded');
    } else {
      vscode.window.showWarningMessage(
        'Kumi: functions-reference.json not found. Run "bin/kumi-doc-gen" to generate it.'
      );
    }
  } catch (e) {
    console.error('Failed to load functions reference:', e);
    vscode.window.showErrorMessage(
      'Kumi: Error loading functions reference: ' + String(e)
    );
  }

  // Register completion provider for both Ruby and Kumi files
  const completionProvider = vscode.languages.registerCompletionItemProvider(
    [
      { language: 'ruby', scheme: 'file' },
      { language: 'kumi', scheme: 'file' }
    ],
    new FunctionCompletionProvider(),
    ':'  // trigger on ':'
  );

  // Register hover provider for both Ruby and Kumi files
  const hoverProvider = vscode.languages.registerHoverProvider(
    [
      { language: 'ruby', scheme: 'file' },
      { language: 'kumi', scheme: 'file' }
    ],
    new FunctionHoverProvider()
  );

  context.subscriptions.push(completionProvider, hoverProvider);
}

class FunctionCompletionProvider implements vscode.CompletionItemProvider {
  provideCompletionItems(
    document: vscode.TextDocument,
    position: vscode.Position,
    token: vscode.CancellationToken,
    context: vscode.CompletionContext
  ): vscode.CompletionItem[] {
    // Check if we're in an fn(:...) context
    const lineText = document.lineAt(position).text;
    const beforeCursor = lineText.substring(0, position.character);

    if (!beforeCursor.match(/fn\(\s*:\s*$/)) {
      return [];
    }

    // For Ruby files, check if we're inside a schema block
    if (document.languageId === 'ruby') {
      if (!this.isInSchemaBlock(document, position)) {
        return [];
      }
    }

    const completions: vscode.CompletionItem[] = [];

    for (const [alias, funcDef] of Object.entries(functionsData)) {
      const item = new vscode.CompletionItem(
        alias,
        vscode.CompletionItemKind.Function
      );

      item.detail = `${funcDef.id} (arity: ${funcDef.arity})`;
      item.documentation = new vscode.MarkdownString(
        this.getDocumentation(funcDef)
      );
      item.sortText = alias;

      completions.push(item);
    }

    return completions;
  }

  private getDocumentation(funcDef: FunctionDef): string {
    const lines: string[] = [
      `**${funcDef.id}**`,
      '',
      `**Arity:** ${funcDef.arity}`,
    ];

    if (funcDef.params && funcDef.params.length > 0) {
      lines.push('**Parameters:**');
      funcDef.params.forEach((p) => {
        lines.push(`- \`${p.name}\``);
      });
    }

    if (funcDef.dtype) {
      lines.push(`**Type:** ${this.formatType(funcDef.dtype)}`);
    }

    if (funcDef.kernels && Object.keys(funcDef.kernels).length > 0) {
      lines.push('**Kernels:**');
      Object.entries(funcDef.kernels).forEach(([target, id]) => {
        lines.push(`- ${target}: \`${id}\``);
      });
    }

    return lines.join('\n');
  }

  private formatType(dtype: any): string {
    if (!dtype) return 'unknown';

    switch (dtype.rule) {
      case 'same_as':
        return `same as \`${dtype.param}\``;
      case 'scalar':
        return dtype.kind || 'scalar';
      case 'promote':
        return `promoted from ${dtype.params.map((p: string) => `\`${p}\``).join(', ')}`;
      case 'element_of':
        return `element of \`${dtype.param}\``;
      default:
        return dtype.rule;
    }
  }

  private isInSchemaBlock(document: vscode.TextDocument, position: vscode.Position): boolean {
    let braceCount = 0;
    let schemaFound = false;

    // Search backwards from current position to find schema block
    for (let i = position.line; i >= 0; i--) {
      const line = document.lineAt(i).text;

      // Count braces from end of line backwards
      if (i === position.line) {
        // Only count braces before cursor
        for (let j = position.character - 1; j >= 0; j--) {
          if (line[j] === '}') braceCount++;
          if (line[j] === '{') braceCount--;
        }
      } else {
        // Count all braces in the line (right to left)
        for (let j = line.length - 1; j >= 0; j--) {
          if (line[j] === '}') braceCount++;
          if (line[j] === '{') braceCount--;
        }
      }

      // Look for 'schema do' or 'schema {'
      if (line.match(/\bschema\s+(do|{)/)) {
        schemaFound = braceCount <= 0;
        break;
      }
    }

    return schemaFound;
  }
}

class FunctionHoverProvider implements vscode.HoverProvider {
  provideHover(
    document: vscode.TextDocument,
    position: vscode.Position,
    token: vscode.CancellationToken
  ): vscode.ProviderResult<vscode.Hover> {
    const range = document.getWordRangeAtPosition(position);
    if (!range) return null;

    const word = document.getText(range);

    // Check if we're in fn(:word, ...)
    const lineText = document.lineAt(position).text;
    if (!lineText.match(/fn\s*\(\s*:/)) {
      return null;
    }

    // For Ruby files, check if we're inside a schema block
    if (document.languageId === 'ruby') {
      if (!this.isInSchemaBlock(document, position)) {
        return null;
      }
    }

    const funcDef = functionsData[word];
    if (!funcDef) {
      return null;
    }

    const markdown = new vscode.MarkdownString();
    markdown.appendMarkdown(`### \`${funcDef.id}\`\n\n`);

    if (funcDef.aliases && funcDef.aliases.length > 0) {
      markdown.appendMarkdown(
        `**Aliases:** ${funcDef.aliases.map((a) => `\`${a}\``).join(', ')}\n\n`
      );
    }

    markdown.appendMarkdown(`**Arity:** ${funcDef.arity}\n\n`);

    if (funcDef.dtype) {
      markdown.appendMarkdown(`**Type:** ${this.formatType(funcDef.dtype)}\n\n`);
    }

    if (funcDef.params && funcDef.params.length > 0) {
      markdown.appendMarkdown('**Parameters:**\n\n');
      funcDef.params.forEach((p) => {
        markdown.appendMarkdown(`- \`${p.name}\`\n`);
      });
      markdown.appendMarkdown('\n');
    }

    return new vscode.Hover(markdown);
  }

  private formatType(dtype: any): string {
    if (!dtype) return 'unknown';

    switch (dtype.rule) {
      case 'same_as':
        return `same as \`${dtype.param}\``;
      case 'scalar':
        return dtype.kind || 'scalar';
      case 'promote':
        return `promoted from ${dtype.params
          .map((p: string) => `\`${p}\``)
          .join(', ')}`;
      case 'element_of':
        return `element of \`${dtype.param}\``;
      default:
        return dtype.rule;
    }
  }

  private isInSchemaBlock(document: vscode.TextDocument, position: vscode.Position): boolean {
    let braceCount = 0;
    let schemaFound = false;

    // Search backwards from current position to find schema block
    for (let i = position.line; i >= 0; i--) {
      const line = document.lineAt(i).text;

      // Count braces from end of line backwards
      if (i === position.line) {
        // Only count braces before cursor
        for (let j = position.character - 1; j >= 0; j--) {
          if (line[j] === '}') braceCount++;
          if (line[j] === '{') braceCount--;
        }
      } else {
        // Count all braces in the line (right to left)
        for (let j = line.length - 1; j >= 0; j--) {
          if (line[j] === '}') braceCount++;
          if (line[j] === '{') braceCount--;
        }
      }

      // Look for 'schema do' or 'schema {'
      if (line.match(/\bschema\s+(do|{)/)) {
        schemaFound = braceCount <= 0;
        break;
      }
    }

    return schemaFound;
  }
}

export function deactivate() {}
