import { Injectable } from '@angular/core';
import { BehaviorSubject, Observable } from 'rxjs';

export interface QuickReply {
  id: string;
  text: string;
  icon: string;
  category: 'help' | 'report' | 'check' | 'other';
}

@Injectable({
  providedIn: 'root',
})
export class QuickReplyService {
  private quickReplies: QuickReply[] = [
    {
      id: 'it-optimizer',
      text: 'IT_Optimizer_Tool',
      icon: 'bug_report',
      category: 'report',
    },
  ];

  private suggestedMessagesSubject = new BehaviorSubject<string[]>([]);
  public suggestedMessages$ = this.suggestedMessagesSubject.asObservable();

  constructor() {}

  /**
   * Get quick reply buttons
   */
  getQuickReplies(): QuickReply[] {
    return this.quickReplies;
  }

  /**
   * Get quick replies by category
   */
  getQuickRepliesByCategory(category: string): QuickReply[] {
    return this.quickReplies.filter((reply) => reply.category === category);
  }

  /**
   * Set suggested messages based on conversation context
   */
  setSuggestedMessages(suggestions: string[]): void {
    this.suggestedMessagesSubject.next(suggestions);
  }

  /**
   * Get current suggested messages
   */
  getSuggestedMessages(): Observable<string[]> {
    return this.suggestedMessagesSubject.asObservable();
  }

  /**
   * Clear suggested messages
   */
  clearSuggestedMessages(): void {
    this.suggestedMessagesSubject.next([]);
  }
}
